#!/usr/bin/env bash
# Run the OpenTH multiplayer server natively (a systemd service) with the
# headless referee, which repairs desyncs and lets a dropped player rejoin
# (docs/multiplayer/referee.md). Ubuntu or Debian; run as root (sudo).
#
#   sudo bash setup-referee-host.sh --release mp-test-c364e17a [--data DIR] [--port 47800] [--motd TEXT]
#        [--name eu2] [--experts "Argus,Matroftt"]
#   (a stable release is named mp-stable-<commit>)
#
# --release  a test release of openth-org/openth: its Linux package
#            is the referee, and the server code comes from the same commit.
#            The players must run that release (the build ids must match).
# --code     optional: the server code and the referee's and bots' scripts
#            from another branch or commit (newer than the release), for
#            server-side changes the players' build does not need (bots, the
#            server itself). Default: the release's own commit.
# --data     your Theme Hospital folder (the one with DATA, QDATA, ...), the
#            first time: it is copied to /opt/openth/thdata, readable only
#            by the service account. It is not part of any release.
#
# Advice for the bots from a language model (mp_server/corsixth_mp/advisor.py):
# put the Anthropic API key into /etc/openth-secrets.env yourself, as
#   ANTHROPIC_API_KEY=...   (root:openth, mode 640)
# This script never writes that file; the service reads it if it is there,
# and without it the bots play on their own rules. Optional settings there
# too: OPENTH_AI_MODEL, OPENTH_AI_DAILY_USD (default 3).
#
# A daily report to Discord at 7:00 (Europe/Prague): yesterday's games, how
# long, people and bots, and what the advice cost (corsixth_mp/daily_report.py).
# Put the webhook into the same secrets file yourself, as
#   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
# Without it nothing is posted. --name names this server in the report
# (default: the host's name; kept from the last run).
#
# A line in the team's #development channel when a new release lands here
# ("A new release, mp-test-..., is now on server eu2 ... Details: <link>",
# the link to the release's post in the releases channel, else to GitHub):
# put that channel's webhook into the secrets file as
#   DISCORD_DEV_WEBHOOK_URL=https://discord.com/api/webhooks/...
# Posted only when the release differs from the one this server ran before.
#
# Bots that learn from expert players (corsixth_mp/learn.py): --experts lists
# their player names (kept from the last run; --experts none: nobody). While
# one of them plays, the referee saves the game at every year's end and at
# the game's end into /var/lib/openth/learn; every morning at 6:30 (Prague)
# the bots learn from the new saves (hard bots build that way), and the
# daily report says whose.
#
# The game pack of the release (openth-pack-<build>.bin and .sig, made and
# signed by the release maker; corsixth_mp/packs.py), if it has one: players
# of another build download it in the game instead of the release's page.
#
# The service is openth (logs: journalctl -u openth), its settings
# /etc/openth.env (OPENTH_... names), its account openth (/var/lib/openth).
# Servers set up before 2026-11-27 had the first names (service corsixth-mp,
# /opt/corsixth-mp, /etc/corsixth-mp.env, account corsixth): this script moves
# them to the new names once, drop-ins included. The server code still reads
# the first setting names (CORSIXTH_MP_...) too.
#
# Safe to run again, e.g. with the next release. Restarting the service drops
# every connected player: check that nobody is playing first.
set -euo pipefail

RELEASE=""
CODE=""
DATA=""
PORT=47800
MOTD="OpenTH server (with referee)"
NAME=""
EXPERTS="-"
REPO=openth-org/openth
BASE=/opt/openth

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) RELEASE=$2; shift 2 ;;
    --code) CODE=$2; shift 2 ;;
    --data) DATA=$2; shift 2 ;;
    --port) PORT=$2; shift 2 ;;
    --motd) MOTD=$2; shift 2 ;;
    --name) NAME=$2; shift 2 ;;
    --experts) EXPERTS=$2; shift 2 ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "Unknown option $1 (see --help)" >&2; exit 2 ;;
  esac
done
die() { echo "ERROR: $*" >&2; exit 1; }
say() { printf '\n== %s\n' "$*"; }
[[ $(id -u) -eq 0 ]] || die "run as root, e.g. sudo bash $0 ..."
[[ "$RELEASE" =~ ^mp-(test|stable)-([0-9a-f]{7,40})$ ]] || die "--release must look like mp-test-<commit> or mp-stable-<commit>"
SHA=${BASH_REMATCH[2]}
export DEBIAN_FRONTEND=noninteractive

say "Packages: Python, git, and the libraries the game binary links against"
apt-get update -q >/dev/null
apt-get install -y -q --no-install-recommends python3 python3-venv git curl ca-certificates libgomp1 \
  libpulse0 libasound2t64 libjack-jackd2-0 libpipewire-0.3-0t64 libx11-6 libxext6 libxcursor1 \
  libxi6 libxfixes3 libxrandr2 libxss1 libgbm1 libwayland-egl1 libwayland-client0 \
  libwayland-cursor0 libdecor-0-0 >/dev/null

# This script writes the settings as OPENTH_...; server code from before
# 2026-11-27 reads only CORSIXTH_MP_... and would start without its referee
# and bots. Check before anything on this server changes.
ref=${CODE:-$RELEASE}
init=$(curl -fsSL "https://raw.githubusercontent.com/$REPO/$ref/mp_server/corsixth_mp/__init__.py") ||
  die "cannot read the server code of $ref from GitHub"
if ! grep -q "OPENTH_" <<<"$init"; then
  die "the server code of $ref is from before 2026-11-27 and does not know the OPENTH_ settings this script writes: use a newer release, or add --code master"
fi

# The first names (until 2026-11-27): move them to openth once.
if [[ -e /etc/systemd/system/corsixth-mp.service || -d /opt/corsixth-mp || -f /etc/corsixth-mp.env ]] ||
   id corsixth >/dev/null 2>&1; then
  say "Moving the server from its first names (corsixth-mp) to openth"
  for u in corsixth-mp-report.timer corsixth-mp-learn.timer corsixth-mp.service \
           corsixth-mp-report.service corsixth-mp-learn.service; do
    systemctl disable --now "$u" >/dev/null 2>&1 || true
  done
  for u in corsixth-mp.service corsixth-mp-report.service corsixth-mp-report.timer \
           corsixth-mp-learn.service corsixth-mp-learn.timer; do
    new=openth${u#corsixth-mp}
    # Drop-ins (OOMPolicy, the shared bot learning, ...) go with their unit.
    if [[ -d /etc/systemd/system/$u.d ]]; then
      mkdir -p "/etc/systemd/system/$new.d"
      for f in "/etc/systemd/system/$u.d"/*; do
        [[ -e "$f" ]] || continue
        if [[ -e "/etc/systemd/system/$new.d/${f##*/}" ]]; then
          die "both $f and /etc/systemd/system/$new.d/${f##*/} exist: keep one"
        fi
        mv "$f" "/etc/systemd/system/$new.d/"
        echo "   drop-in $f -> $new.d/"
      done
      rmdir "/etc/systemd/system/$u.d"
    fi
    rm -f "/etc/systemd/system/$u"
  done
  systemctl daemon-reload
  if [[ -d /opt/corsixth-mp ]]; then
    [[ -e "$BASE" ]] && die "both /opt/corsixth-mp and $BASE exist: keep one"
    mv /opt/corsixth-mp "$BASE"
    rm -rf "$BASE/venv" # (its scripts name the old folder: made again below)
  fi
  for f in "" -secrets; do
    if [[ -f /etc/corsixth-mp$f.env ]]; then
      [[ -e /etc/openth$f.env ]] && die "both /etc/corsixth-mp$f.env and /etc/openth$f.env exist: keep one"
      mv "/etc/corsixth-mp$f.env" "/etc/openth$f.env"
    fi
  done
  if id corsixth >/dev/null 2>&1; then
    id openth >/dev/null 2>&1 && die "both accounts corsixth and openth exist: keep one"
    left=$(pgrep -u corsixth -a || true)
    [[ -z "$left" ]] || die "programs of the account corsixth still run: $left"
    # (Same user and group ids: every file it owned stays its own.)
    usermod -l openth -d /var/lib/openth -m corsixth
    groupmod -n openth corsixth
  fi
  if [[ -d /var/lib/corsixth && ! -e /var/lib/openth ]]; then mv /var/lib/corsixth /var/lib/openth; fi
  echo "   now: service openth, $BASE, /etc/openth.env, account openth, /var/lib/openth"
fi

say "Service account openth"
id openth >/dev/null 2>&1 || useradd --system --home /var/lib/openth --create-home \
  --shell /usr/sbin/nologin openth
mkdir -p "$BASE/referee" /var/lib/openth/referee-work /var/lib/openth/learn
chown -R openth:openth /var/lib/openth

if [[ -n "$DATA" ]]; then
  say "Game data from $DATA"
  [[ -d "$DATA" ]] || die "no folder $DATA"
  rm -rf "$BASE/thdata" && mkdir -p "$BASE/thdata"
  cp -r "$DATA" "$BASE/thdata/themehos"
fi
[[ -d "$BASE/thdata/themehos" ]] || die "no game data yet: pass --data once"
chown -R root:openth "$BASE/thdata" && chmod -R u=rwX,g=rX,o= "$BASE/thdata"

say "Server code at ${CODE:-$SHA}"
if [[ ! -d "$BASE/src/.git" ]]; then git clone -q "https://github.com/$REPO.git" "$BASE/src"; fi
git -C "$BASE/src" fetch -q origin
if [[ -n "$CODE" ]]; then
  # A branch name (origin/<branch>) or a commit.
  if git -C "$BASE/src" rev-parse -q --verify "origin/$CODE" >/dev/null; then CODE="origin/$CODE"; fi
  git -C "$BASE/src" checkout -q -f "$CODE"
  git -C "$BASE/src" merge-base --is-ancestor "$SHA" HEAD || die "--code $CODE does not contain the release's commit $SHA"
else
  git -C "$BASE/src" checkout -q -f "$SHA"
fi
git -C "$BASE/src" log --oneline -1

say "Python environment for the server (the Anthropic SDK for the bots' advice)"
if [[ ! -x "$BASE/venv/bin/python" ]]; then python3 -m venv "$BASE/venv"; fi
"$BASE/venv/bin/pip" install -q --upgrade anthropic

say "Referee: the Linux package of $RELEASE"
R="$BASE/referee/$SHA"
rm -rf "$R" && mkdir -p "$R/scripts/multiplayer"
# OpenTH-<sha>-linux-x86_64.tar.gz (folder OpenTH, program openth) since the
# rename; older releases have CorsixTH-Multiplayer-<sha>-... (folder
# CorsixTH-Multiplayer, program corsix-th).
pkg=""
for name in OpenTH CorsixTH-Multiplayer; do
  url="https://github.com/$REPO/releases/download/$RELEASE/$name-$SHA-linux-x86_64.tar.gz"
  if curl -fsSL "$url" | tar xz -C "$R"; then pkg=$name; break; fi
done
[[ -n "$pkg" ]] || die "no Linux package in $RELEASE"
mv "$R/$pkg" "$R/game"
BIN=$R/game/openth
[[ -x "$BIN" ]] || BIN=$R/game/corsix-th
ln -s game "$R/CorsixTH" # referee.lua loads <source>/CorsixTH/CorsixTH.lua
# The referee, and the bots (computer players) a room owner adds, if this
# release has them, and what the bots learn with (bot_learned.lua; the
# nightly learning reads saves with layout_dump.lua and layout_learn.py; what
# they say comes through bot_chat.lua; bot_host.lua: one game for all the
# bots of a room).
for f in referee.lua probe_builder.lua bot.lua bot_host.lua bot_manager.lua bot_learned.lua bot_chat.lua layout_dump.lua layout_learn.py; do
  if [[ -f "$BASE/src/scripts/multiplayer/$f" ]]; then cp "$BASE/src/scripts/multiplayer/$f" "$R/scripts/multiplayer/"; fi
done
chown -R root:openth "$BASE/referee" "$BASE/src" && chmod -R g+rX,o= "$BASE/referee"
missing=$(LD_LIBRARY_PATH="$R/game/lib" ldd "$BIN" | grep "not found" || true)
[[ -z "$missing" ]] || die "the game binary misses libraries: $missing"

say "Game pack of $RELEASE, if it has one"
P="$BASE/packs"
PACKS=""
mkdir -p "$P"
build=$(PYTHONPATH="$BASE/src/mp_server" "$BASE/venv/bin/python" -c \
  'import sys; from corsixth_mp.builds import lua_checksum; print(lua_checksum(sys.argv[1]))' "$R/CorsixTH/Lua")
for ext in bin sig; do
  f="$P/openth-pack-$build.$ext"
  if curl -fsSL -o "$f.part" "https://github.com/$REPO/releases/download/$RELEASE/openth-pack-$build.$ext"; then
    mv "$f.part" "$f"
  else
    rm -f "$f.part" "$f"
  fi
done
# (Only this build's: the server offers its own.)
find "$P" -maxdepth 1 -type f ! -name "openth-pack-$build.*" -delete
if [[ -f "$P/openth-pack-$build.bin" && -f "$P/openth-pack-$build.sig" ]]; then
  PACKS="$P"
  echo "players of other builds can download build $build in the game"
else
  rm -f "$P/openth-pack-$build".*
  echo "no game pack in $RELEASE: players of other builds are sent to its page"
fi
chown -R root:openth "$P" && chmod -R g+rX,o= "$P"

say "Settings (/etc/openth.env) and the service"
# (The release this server ran until now: a new one is announced at the end.)
# (Kept settings may still have their first names, CORSIXTH_MP_...)
setting() { (sed -n -E "s/^(OPENTH|CORSIXTH_MP)_$1=//p" /etc/openth.env 2>/dev/null || true) | head -1; }
OLD_RELEASE=$(setting RELEASE)
if [[ -z "$NAME" ]]; then
  NAME=$(setting SERVER_NAME)
fi
NAME=${NAME:-$(hostname)}
if [[ "$EXPERTS" == "-" ]]; then
  EXPERTS=$(setting EXPERTS)
fi
[[ "$EXPERTS" == "none" ]] && EXPERTS=""
cat > /etc/openth.env <<EOF
# Written by setup-referee-host.sh for $RELEASE. The referee build must match
# the players' build: players of other builds are told to get this release.
OPENTH_MOTD=$MOTD
OPENTH_RELEASE=$RELEASE
# Signed game pack of this build, downloaded by players of other builds.
OPENTH_PACKS=$PACKS
OPENTH_REFEREE_BINARY=$BIN
OPENTH_REFEREE_SOURCE=$R
OPENTH_REFEREE_DATA=$BASE/thdata/themehos
OPENTH_REFEREE_LUA_CPATH=$R/game/lua/?.so
OPENTH_REFEREE_LUA_PATH=$R/game/lua/?.lua;$R/game/lua/?/init.lua
OPENTH_REFEREE_WORKDIR=/var/lib/openth/referee-work
LD_LIBRARY_PATH=$R/game/lib
OPENTH_SERVER_NAME=$NAME
# Bots learn from these players' games (setup --experts; empty: nobody).
OPENTH_LEARN_DIR=/var/lib/openth/learn
OPENTH_EXPERTS=$EXPERTS
EOF
chmod 644 /etc/openth.env
cat > /etc/systemd/system/openth.service <<EOF
[Unit]
Description=OpenTH multiplayer server (with the headless referee)
After=network-online.target
Wants=network-online.target

[Service]
User=openth
Group=openth
WorkingDirectory=$BASE/src/mp_server
EnvironmentFile=/etc/openth.env
EnvironmentFile=-/etc/openth-secrets.env
ExecStart=$BASE/venv/bin/python -m corsixth_mp --host 0.0.0.0 --port $PORT
Restart=on-failure
RestartSec=5
KillMode=control-group
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/openth
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictSUIDSGID=yes
LockPersonality=yes
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# The Docker server (setup-vps.sh) uses the same port: stop it.
for c in openth-server corsixth-mp-server; do
  if command -v docker >/dev/null && docker ps --format '{{.Names}}' | grep -qx "$c"; then
    say "Stopping the Docker server $c (kept for going back: docker compose up -d in its folder)"
    docker stop "$c" >/dev/null
  fi
done
# The daily report (posted only if DISCORD_WEBHOOK_URL is in the secrets).
cat > /etc/systemd/system/openth-report.service <<EOF
[Unit]
Description=OpenTH: yesterday's games to Discord

[Service]
Type=oneshot
User=openth
Group=openth
WorkingDirectory=$BASE/src/mp_server
EnvironmentFile=/etc/openth.env
EnvironmentFile=-/etc/openth-secrets.env
ExecStart=$BASE/venv/bin/python -m corsixth_mp.daily_report
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
EOF
cat > /etc/systemd/system/openth-report.timer <<EOF
[Unit]
Description=OpenTH: the daily report at 7:00 Prague time

[Timer]
OnCalendar=*-*-* 07:00:00 Europe/Prague
Persistent=true

[Install]
WantedBy=timers.target
EOF
# The bots learn from the night's saves of expert players, before the report.
cat > /etc/systemd/system/openth-learn.service <<EOF
[Unit]
Description=OpenTH: the bots learn from expert players' saved games

[Service]
Type=oneshot
User=openth
Group=openth
WorkingDirectory=$BASE/src/mp_server
EnvironmentFile=/etc/openth.env
ExecStart=$BASE/venv/bin/python -m corsixth_mp.learn
Nice=10
TimeoutStartSec=2h
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/openth
PrivateTmp=yes
EOF
cat > /etc/systemd/system/openth-learn.timer <<EOF
[Unit]
Description=OpenTH: the bots learn at 6:30 Prague time

[Timer]
OnCalendar=*-*-* 06:30:00 Europe/Prague
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now openth-report.timer >/dev/null 2>&1
systemctl enable --now openth-learn.timer >/dev/null 2>&1
systemctl enable openth.service >/dev/null 2>&1
systemctl restart openth.service
sleep 2
systemctl is-active --quiet openth.service || die "the service did not start: journalctl -u openth"
python3 - "$PORT" <<'PY'
import socket, sys, time
# The server listens after a few seconds (eu1 2026-11-12: 3.4 s).
for attempt in range(30):
    try:
        s = socket.create_connection(("127.0.0.1", int(sys.argv[1])), 5)
        break
    except ConnectionRefusedError:
        if attempt == 29:
            raise
        time.sleep(1)
s.sendall(b"HEALTH\n")
print("   " + s.recv(200).decode().strip())
PY
# Old referee builds are not needed any more.
find "$BASE/referee" -mindepth 1 -maxdepth 1 -type d ! -name "$SHA" -exec rm -rf {} +
say "Done: the server runs $RELEASE with the referee on port $PORT"
# One line in #development when the release changed (DISCORD_DEV_WEBHOOK_URL
# in the secrets; the address is never printed).
DEV_HOOK=$( (sed -n 's/^DISCORD_DEV_WEBHOOK_URL=//p' /etc/openth-secrets.env 2>/dev/null || true) | head -1)
if [[ -n "$DEV_HOOK" && "$RELEASE" != "$OLD_RELEASE" ]]; then
  where=${NAME:-$(hostname)}
  [[ "$where" =~ ^[a-z]{2,4}[0-9]+$ ]] && where="$where ($where.openth.org)"
  DEV_HOOK=$DEV_HOOK python3 - "$RELEASE" "$where" <<'PY' || echo "   (the #development line could not be posted)"
import calendar, json, os, re, sys, time, urllib.request
release, where = sys.argv[1], sys.argv[2]
# The release's own post in the releases channel, if its poster
# (corsixth_mp/release_post.py) left its address in the notes; a release
# published a moment ago may not have it yet. Else the release's page.
link = f"https://github.com/openth-org/openth/releases/tag/{release}"
for attempt in range(8):
    try:
        req = urllib.request.Request(f"https://api.github.com/repos/openth-org/openth/releases/tags/{release}",
                                     headers={"User-Agent": "openth-deploy"})
        rel = json.load(urllib.request.urlopen(req, timeout=15))
    except OSError:
        break
    m = re.search(r"<!-- discord-post: (https://discord\.com/channels/\d+/\d+/\d+) -->", rel.get("body") or "")
    if m:
        link = m.group(1)
        break
    published = calendar.timegm(time.strptime(rel.get("published_at") or "1970-01-01T00:00:00Z", "%Y-%m-%dT%H:%M:%SZ"))
    if time.time() - published > 900 or attempt == 7:
        break
    time.sleep(15)
text = f"A new release, **{release}**, is now on server {where}. Details: <{link}>"
req = urllib.request.Request(os.environ["DEV_HOOK"], data=json.dumps({"content": text}).encode(),
                             headers={"Content-Type": "application/json", "User-Agent": "openth-deploy"})
urllib.request.urlopen(req, timeout=15).read()
print("   Posted in #development: " + text)
PY
fi
echo "   Logs: journalctl -u openth -f; referee logs in /var/lib/openth/referee-work"
if [[ -n "$EXPERTS" ]]; then
  echo "   Bots learn from: $EXPERTS (saves in /var/lib/openth/learn; journalctl -u openth-learn)"
fi
