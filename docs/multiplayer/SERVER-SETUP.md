# Setting up your own multiplayer server (with the referee)

This guide sets up a server like OpenTH's own (`eu1.openth.org`,
`us1.openth.org`, ...): the lobby where players make and join rooms, plus
the **referee**, a copy of every game that runs on the server. The referee
repairs games that get out of sync within a moment, lets a player whose game
crashed join again, and runs the computer players (bots). One script does
the whole installation.

You need to be comfortable with typing commands into an SSH session. It
takes about 15 minutes.

## 1. What you need

- **A Linux server (VPS)** with a public IPv4 address, from any provider
  (Hetzner, OVH, DigitalOcean, ...):
  - **Ubuntu 24.04 or newer**, or **Debian 13**, on a normal **x86_64** (Intel or
    AMD) machine. ARM servers do not work: the referee is the game's Linux
    x86_64 build.
  - **2 CPU cores and 4 GB of memory**, plus 4 GB of swap (step 6).
    Every running game has a referee, and every bot in it is a game of its
    own: each takes 300 to 450 MB (the most on a big map such as Mount
    Everest, late in the game). The server itself takes about 100 MB. So a
    full room of eight with seven bots needs about 3.5 GB; a room of people
    without bots needs only its referee. OpenTH's servers have exactly this.
  - **20 GB of disk** is plenty.
- **SSH access** with sudo rights (the provider tells you how; use an SSH key,
  not a password).
- **Your own copy of Theme Hospital** (the full game, not the demo). The
  referee plays the game too, so the server needs the game files. They are not
  part of any download here and must not be shared publicly.
- **Theme Hospital game files for the referee.** Players with another
  edition (other multiplayer maps and level settings) can play too: their
  game starts from the referee's instead of their own level files. OpenTH's
  servers use the **GOG** edition.

## 2. Firewall and security

### Open only SSH and the game port

Players connect on **TCP port 47800** (you can pick another one, see step 5).

- If your provider has a firewall in its web control panel (Hetzner, OVH,
  ...), allow incoming **TCP 22** (SSH) and **TCP 47800** there. This is the
  most reliable way.
- Or, on the server itself with `ufw` (check that SSH stays open, or you lock
  yourself out):

```bash
sudo ufw allow 22/tcp
sudo ufw allow 47800/tcp
sudo ufw enable
```

### Block repeated failed SSH logins (fail2ban)

Any server on the internet gets thousands of password guesses on SSH (port
22) a day. **fail2ban** watches the SSH log and blocks an address on port 22
for an hour after 5 failed logins within 10 minutes. OpenTH's servers run
exactly this setup.

Install it and write its settings:

```bash
sudo apt-get update
sudo apt-get install -y fail2ban
sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd
# Never block these (optional): your own address, e.g. 203.0.113.7
# ignoreip = 127.0.0.1/8 ::1 203.0.113.7

[sshd]
enabled = true
port = ssh
EOF
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
```

If your SSH runs on another port than 22, write that number instead of `ssh`
in `port = ssh`.

Check that it watches SSH (it may take a few seconds after the restart):

```bash
sudo fail2ban-client status sshd
```

It shows `Currently failed`, `Total banned` and the blocked addresses. On a
new server the numbers grow within hours. It works together with `ufw` and
with the provider's firewall.

If you block yourself (5 wrong passwords or keys in 10 minutes), wait an hour,
or log in from another network or through the provider's web console and
unblock your address:

```bash
sudo fail2ban-client set sshd unbanip 203.0.113.7
```

Two more good habits: log in with an SSH key, not a password, and keep the
server updated (`sudo apt update && sudo apt upgrade`).

## 3. Copy your Theme Hospital files to the server

Find the folder with the game files: it has the folders **DATA**, **QDATA**,
**LEVELS** and **SOUND** inside. It is the folder you chose when the game first
asked where Theme Hospital is.

- GOG on a Mac: `/Applications/Theme Hospital.app/Contents/Resources/game`
- GOG on Windows: inside the folder GOG installed the game into (for example
  `C:\GOG Games\Theme Hospital`); look for the folder with DATA and QDATA in it.

Copy that whole folder to your home folder on the server and call it
`themehos`. From a Mac (Terminal) or Windows (PowerShell), replace the folder
and the server address with yours:

```bash
scp -r "/Applications/Theme Hospital.app/Contents/Resources/game" you@your.server:themehos
```

Check on the server that it arrived (you should see DATA, QDATA, LEVELS, ...):

```bash
ls ~/themehos
```

## 4. Pick the game version

Every player and the server must run **the same release**. Open the releases
page: <https://github.com/openth-org/openth/releases>

- **Stable** releases are called `mp-stable-<number>` (the one marked
  *Latest*). Every OpenTH server except eu2 runs the newest stable one.
- **Test** releases are called `mp-test-<number>` (marked *Pre-release*). eu2
  runs the newest test one.

Note the name of the release you want, for example `mp-stable-18d0554f`.
Your players download the same release for Windows, Mac or Linux. (A player
whose game is too old or too new for your server is offered your server's
version in the game; see step 8.)

## 5. Install the server

Log in to the server with SSH and run these two commands. Replace the
release name, and the welcome text (`--motd`, shown to players when they
connect) with your own:

```bash
curl -fsSLO https://raw.githubusercontent.com/openth-org/openth/master/mp_server/deploy/setup-referee-host.sh
sudo bash setup-referee-host.sh --release mp-stable-18d0554f --data ~/themehos --motd "Welcome to my OpenTH server"
```

Add `--port 47900` if you want another port than 47800 (then open that one in
step 2 instead).

The script installs what the server needs, makes a service account
`openth`, copies your game files to `/opt/openth/thdata` (readable only
by that account), downloads the server code, the game for the referee and
the release's game pack (step 8), and starts the server as a system service
that also starts by itself after a reboot. It ends with:

```
== Done: the server runs mp-stable-18d0554f with the referee on port 47800
```

Once it says Done, you can delete your copy in `~/themehos` if you like
(`rm -rf ~/themehos`); the server keeps its own.

## 6. Memory: swap and a crash guard

The script does not do this part; do it once, right after step 5.

When the memory runs out, Linux stops one program to free some: usually a
bot. Without the guard below, the whole server stops with it and every game
on it ends. With it, only that one program stops and the other games go on.
The swap gives the server room before it comes to that.

Make 4 GB of swap (if `swapon --show` already lists some, make only the
rest: `-l 3G` next to 1 GB that is there):

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-openth-swap.conf
sudo sysctl -p /etc/sysctl.d/99-openth-swap.conf
```

(`swappiness=10` keeps the games in memory and uses the swap only when
memory is short.)

The crash guard:

```bash
sudo mkdir -p /etc/systemd/system/openth.service.d
printf '[Service]\nOOMPolicy=continue\n' | sudo tee /etc/systemd/system/openth.service.d/oom.conf
sudo systemctl daemon-reload
```

Both stay after a reboot and after every update with the script. Check with
`free -m`: the line `Swap:` shows 4095 in total.

## 7. Check that it works

Look at the server's log:

```bash
sudo journalctl -u openth -n 30
```

You should see these lines (the numbers differ):

```
headless referee enabled: /opt/openth/referee/<commit>/game/openth
players must have build 60acf5b8 (mp-stable-18d0554f)
players must have Theme Hospital data 899c66d0
```

`899c66d0` means the GOG edition. Players with another edition get the
referee's game at the start of each game (the log says `has Theme Hospital
data ... gets the referee's game`).

Then try it from the game: main menu, **Multiplayer**, type your server's
address with the port into the address box (for example
`203.0.113.25:47800`, or a name like `play.example.com:47800` if you have a
domain pointing at the server), your name, **Connect**. Make a room, click an
empty place to add a bot, and start: if the bot plays along, the referee
works.

To watch the log live while people play: `sudo journalctl -u openth -f`
(Ctrl+C to stop watching).

## 8. Updating to a new release

When a new release comes out, run the script again with its name, **without
`--data`** (the server keeps the game files from the first time):

```bash
curl -fsSLO https://raw.githubusercontent.com/openth-org/openth/master/mp_server/deploy/setup-referee-host.sh
sudo bash setup-referee-host.sh --release mp-stable-NEWNUMBER --motd "Welcome to my OpenTH server"
```

- **Servers set up before 27 November 2026** have the first names: the
  service `corsixth-mp` (and `corsixth-mp-learn`, `corsixth-mp-report`),
  `/opt/corsixth-mp`, `/etc/corsixth-mp.env` and `-secrets.env`, the account
  `corsixth` and `/var/lib/corsixth`. The next run of the script moves them
  all to the `openth` names in this guide, with your secrets, the bots'
  learning and any drop-ins (like the crash guard of step 6). Settings with
  their first names (`CORSIXTH_MP_...`) still work.
- **Updating restarts the server and drops everybody who is playing.** Check
  that nobody is in a game first (the log shows the rooms).
- After the update, players with another version are offered **"Get the
  server's version of the game"** when they connect: the game downloads it
  (about 3 MB), restarts as that version and joins your server again. This
  works for players whose game is a release of 19 November 2026
  (`mp-stable-b56bdcce`) or newer, and only if the release has a game pack
  (all OpenTH releases since then do; the script says `no game pack` if
  not). A release that also changes the game's engine (as a new version of
  CorsixTH underneath can) cannot be fetched this way by games from before
  it. Players who cannot switch are told which release to download, with a
  link; they do that once.
- **Never** pass `--data /opt/openth/thdata/...`: the script empties that
  folder first, and your game files would be gone. To change the game files,
  copy them to `~/themehos` again as in step 3 and pass `--data ~/themehos`.

## 9. Everyday commands

| What | Command |
|---|---|
| Is it running? | `systemctl status openth` |
| Last 50 log lines | `sudo journalctl -u openth -n 50` |
| Watch the log | `sudo journalctl -u openth -f` |
| Restart (drops players) | `sudo systemctl restart openth` |
| Stop | `sudo systemctl stop openth` |
| Memory and swap in use | `free -m` |
| Addresses blocked by fail2ban | `sudo fail2ban-client status sshd` |
| Settings (welcome text, release) | `/etc/openth.env` (restart after a change) |
| One game's referee log | `/var/lib/openth/referee-work/<room>-<number>/referee.log` |
| What the bots learnt last | `sudo journalctl -u openth-learn -n 20` |
| Let the bots learn now (not wait for the morning) | `sudo systemctl start openth-learn` |

## 10. When something goes wrong

- **The game cannot connect at all:** the port is closed. Check the
  provider's firewall and `ufw` (step 2), and that the service runs
  (`systemctl status openth`).
- **"Other game version: get ... on GitHub":** the player's game is not the
  release the server runs, and it cannot fetch it by itself (too old, or the
  server's release has another engine; step 8). They download the release
  it names, once.
- **"Your Theme Hospital files differ from this server's":** only on a
  server without the referee (`OPENTH_DATA` set): the player's edition
  differs from the server's. With the referee such players are let in.
- **The script stops with "the game binary misses libraries":** the server
  is not Ubuntu 24.04+/Debian 13, or not x86_64.
- **The log says "referee build ... differs":** the server code and the
  referee are from different releases; run the script again with one
  `--release`.
- **A game got out of sync:** the referee repairs it by itself within a
  moment; the log shows `state of ...` lines about it. If you want the cause
  found, send those log lines to us, in an
  [issue on GitHub](https://github.com/openth-org/openth/issues) or on
  [Discord](https://openth.org/discord).
- **A bot left its game, or the whole server stopped, during a big game:**
  the memory ran out. `sudo journalctl -k | grep -i "out of memory"` shows
  it. Add the swap and the crash guard (step 6), or play with fewer bots.
- **The bots do not build like your experts (section 11):** only normal and
  hard bots do, in games started after the morning's learning. See what it
  learnt with `sudo journalctl -u openth-learn -n 20` (a save it could
  not read is named there and tried again the next morning). Nothing is
  saved while an expert plays under another name, or in a hospital a bot
  played for a while (for a player who left).

## 11. Bots that learn from your best players

The bots can learn to build like the best players on your server: the size
of each room, where every desk, bed and radiator goes, and, on a map and
starting place such a player has played, their whole hospital (where each
room is, the reception, benches, drinks machines...). It needs the referee
(this guide's setup), not the Docker server.

Name those players (their names in the game, any case, separated by commas)
when you install or update:

```bash
sudo bash setup-referee-host.sh --release mp-stable-NEWNUMBER --experts "Argus,Matroftt"
```

The names are kept for later updates; `--experts none` stops it. (Or edit
`OPENTH_EXPERTS=` in `/etc/openth.env` and restart the service.)

What happens then:

- While one of them plays, the game's referee saves the game at the end of
  every game year and when the game ends, into
  `/var/lib/openth/learn/saves` (a few MB each), if they did something in
  the game since the last save. A hospital a bot played for a while, for a
  player who left, is never learnt from.
- **Sharing a hospital:** an expert who plays with an assistant bot, or
  shares a hospital with other people, is learnt from too, but only from
  what they built themselves: rooms and objects the assistant or the others
  placed are left out. This needs the test release `mp-test-4ffe5182`
  (22 November 2026) or newer; older releases save nothing for a shared
  hospital.
- Every morning at 6:30 (Prague time) the server reads the new saves and
  writes what the bots learnt to `/var/lib/openth/learn/learned.lua`. Each
  game counts once, as its latest save has it (a game continued from a save
  is saved again: its saves are recognised by the rooms and corridor objects
  they share). Normal and hard bots of games started after that build that
  way (a new bot is a normal one; the room's owner right-clicks its place to
  pick easy or hard); easy bots keep their own simple rules, and so does a
  bot that plays for a player who left.
- The daily Discord report names the games and players learnt from that
  night, each game by its latest save and how many saves it had (nothing is
  said on a night without new ones).

Tell the players you name that their games are saved on your server for
this. To start over, stop the service and delete
`/var/lib/openth/learn/layouts.jsonl` and `learned.lua` (the saves stay;
delete `state.json` too to learn from them again).

To give another server what this one learnt, copy `layouts.jsonl` there
(into the same folder, owned by `openth`) and run
`sudo systemctl start openth-learn` on it.

## 12. Good to know

- Passwords and game traffic are **not encrypted**. Room passwords only keep
  strangers out of a room; do not use a password you use anywhere else.
- Keep the server updated (`sudo apt update && sudo apt upgrade`), log in
  with SSH keys only, and keep fail2ban on (step 2).
- Without a referee, a lighter server without game files exists too (Docker,
  `vps-guide.md`, or plain Python on any computer), but there a game that gets
  out of sync ends, a player who left cannot come back, and there are no bots.
  The technical details of the referee are in `referee.md`.
- **On a LAN without the internet:** the plain server runs on any computer on
  your network, Windows included; see "Playing on a LAN" in
  [`mp_server/README.md`](../../mp_server/README.md). This setup with the
  referee works on a LAN too (a Linux x86-64 computer); it needs the internet
  only while the script downloads the release.

## 13. Optional: advice for the bots, and Discord messages

Both read their secrets from `/etc/openth-secrets.env`, a file the script
never writes. Make it yourself, readable only by root and the service:

```bash
sudo touch /etc/openth-secrets.env
sudo chown root:openth /etc/openth-secrets.env
sudo chmod 640 /etc/openth-secrets.env
sudo nano /etc/openth-secrets.env
```

- **Advice for the bots:** normal and hard bots ask a language model
  (Claude Haiku, through the Anthropic API) for a plan now and then, and use
  it to answer players in the chat. Add a line `ANTHROPIC_API_KEY=...` with
  your key. Optional in the same file: `OPENTH_AI_MODEL` (default
  `claude-haiku-5-5`) and `OPENTH_AI_DAILY_USD`, the most it may cost a
  day (default 3 dollars). Without a key, or over the budget, the bots play on
  their own rules; easy bots never ask.
- **Daily report to Discord** at 7:00 (Europe/Prague): yesterday's games, how
  long, people and bots, and what the advice cost. Add a line
  `DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...`. To name the
  server in the report, add `--name myserver` when you run the script (step 5
  or 8; default: the computer's name, and the script remembers it). Without
  the webhook nothing is posted.
- **A line when the server gets a new release** ("A new release,
  mp-stable-..., is now on server myserver. Details:" and a link to it):
  add a line `DISCORD_DEV_WEBHOOK_URL=https://discord.com/api/webhooks/...`
  with the webhook of the channel it should go to. It is posted when the
  script installs another release than the one before.

Restart the service after changing the file:
`sudo systemctl restart openth` (this drops everybody who is playing).
