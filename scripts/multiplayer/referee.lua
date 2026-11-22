-- Headless referee for one multiplayer room (milestone S3). The server
-- (mp_server) starts it when a room's game starts:
--   corsix-th --interpreter=<this file> --config-file=<generated>
-- It connects to the server as the room's referee, plays the same game as
-- the players (same seed, level, settings and commands) without a screen and
-- without ever issuing a command, and reports a fingerprint for every game
-- hour. The players never wait for it. The server compares the players'
-- fingerprints with the referee's; on a desync, or when a player rejoins, the
-- server asks the referee for a save that everybody loads.
--
-- Environment (set by the server):
--   CORSIXTH_SOURCE      checkout root
--   MP_SERVER            server address host:port
--   MP_REFEREE_ROOM      room name
--   MP_REFEREE_TOKEN     token the server gave this referee
--   MP_LUA_CPATH, MP_LUA_PATH  where to find LuaSocket (if not standard)
-- Learning (the server's settings, docs/multiplayer/referee.md): with
--   CORSIXTH_MP_LEARN_DIR  a folder, and
--   CORSIXTH_MP_EXPERTS    names of expert players ("Argus,Matroftt"),
-- while a person of that name plays their own hospital the referee saves
-- the game at the end of every game year and when the game ends, into
-- <dir>/saves (with a .json beside it: the room, the date, each hospital and
-- whether a bot ever played it), and notes what they build (rooms, objects,
-- moves) in <dir>/builds/<room>.jsonl. layout_learn.py learns from them.
-- An expert who did nothing since the last save (a save loaded and only
-- looked at) is not saved again. A hospital an expert shares is named after
-- all its players ("ARGUS + BOT EDNA" with an assistant): it counts too, and
-- the .json notes who built each room and put down each object in it this
-- game (built), so that only the expert's own work is learnt
-- (mp_server/corsixth_mp/learn.py, own_records).
local args = {...}
local unpack_args = table.unpack or unpack
local source_dir = assert(os.getenv("CORSIXTH_SOURCE"), "Missing CORSIXTH_SOURCE")
local server = assert(os.getenv("MP_SERVER"), "Missing MP_SERVER")
local room = assert(os.getenv("MP_REFEREE_ROOM"), "Missing MP_REFEREE_ROOM")
local token = assert(os.getenv("MP_REFEREE_TOKEN"), "Missing MP_REFEREE_TOKEN")

if os.getenv("MP_LUA_CPATH") then package.cpath = os.getenv("MP_LUA_CPATH") .. ";" .. package.cpath end
if os.getenv("MP_LUA_PATH") then package.path = os.getenv("MP_LUA_PATH") .. ";" .. package.path end

local function log(msg)
  io.stdout:write("[referee " .. room .. "] " .. msg .. "\n")
  io.stdout:flush()
end

local learn_dir = (os.getenv("CORSIXTH_MP_LEARN_DIR") or ""):gsub("[/\\]+$", "")
local experts = {}
-- (A new local: Lua 5.5 does not let a loop variable be assigned to.)
for each in (os.getenv("CORSIXTH_MP_EXPERTS") or ""):gmatch("[^,]+") do
  local name = each:gsub("^%s+", ""):gsub("%s+$", "")
  if name ~= "" then experts[name:upper()] = true end
end
local learning = learn_dir ~= "" and next(experts) ~= nil

local function json_text(v)
  local t = type(v)
  if t == "table" then
    if #v > 0 or next(v) == nil then
      local parts = {}
      for i = 1, #v do parts[i] = json_text(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = json_text(k) .. ":" .. json_text(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
  elseif t == "number" or t == "boolean" then
    return tostring(v)
  end
  return "null"
end

-- Hospitals a bot played at any time in this game (its own bot, or one
-- standing in for a person who left): never learnt from.
local bot_ever = {}
local function note_bots(world)
  local coop = world and world.mp_coop
  if not coop then return end
  for index in pairs(coop.bot_hospitals or {}) do bot_ever[index] = true end
  for index in pairs(coop.standin_hospitals or {}) do bot_ever[index] = true end
end

--! A hospital a person (or a bot) plays, not one of the level's computer
--! rivals (they have names too: HAL, ORAC...).
local function players_hospital(hospital)
  local ai = rawget(_G, "AIHospital")
  return not (ai and class.is(hospital, ai))
end

--! The level's name as text (a campaign level's is a localised string).
local function level_name(world)
  return (tostring(world.map.level_name or ""):gsub("^<LocalisedString> Current value:", ""))
end

--! The experts among the players a hospital is named after: its own
--! player's name ("ARGUS"), or all its players' ("ARGUS + BOT EDNA").
local function experts_in(hospital)
  local out = {}
  for each in (tostring(hospital.name or ""):upper() .. " + "):gmatch("(.-) %+ ") do
    local part = each:gsub("^%s+", ""):gsub("%s+$", "")
    if experts[part] then out[#out + 1] = part end
  end
  return out
end

--! The experts playing now: hospital index -> their names ("ARGUS"), in
--! their own hospital or one they share.
local function experts_playing(world)
  local out = {}
  for index, hospital in ipairs(world and world.hospitals or {}) do
    local names = players_hospital(hospital) and not bot_ever[index] and experts_in(hospital) or {}
    if names[1] then out[index] = table.concat(names, ", ") end
  end
  return out
end

-- The game's lobby (run): its peer_names say who sent a command.
local the_lobby

--! The name of the player who sent a command ("ARGUS", "BOT EDNA"), or nil.
local function sender(cmd)
  local names = the_lobby and the_lobby.peer_names
  local name = names and names[tonumber(cmd.peer)]
  return name and tostring(name):upper() or nil
end

-- Who built what this game in the hospitals with an expert in them: index
-- -> {rooms = {{kind, x, y, by, expert}...}, objects = {{id, x, y, by,
-- expert}...}} (a room by its corner, an object by its tile, as
-- layout_dump.lua has them).
local built = {}

--! Note who built a room (build_room, room_rebuild) or put down an object
--! (place_object, move_object, room_object) in hospital index.
local function note_builder(index, kind, cmd)
  -- (Without the players' names nobody is noted: all counts as the expert's.)
  local by = sender(cmd)
  if not (by and cmd.x and cmd.y) then return end
  local entry = {x = cmd.x, y = cmd.y, by = by, expert = experts[by] and true or false}
  local h = built[index] or {rooms = {}, objects = {}}
  built[index] = h
  if kind == "build_room" or kind == "room_rebuild" then
    -- (room_rebuild names the room by its number, not its kind.)
    if kind == "build_room" and type(cmd.room) == "string" then entry.kind = cmd.room end
    h.rooms[#h.rooms + 1] = entry
  elseif kind == "place_object" or kind == "move_object" or kind == "room_object" then
    if type(cmd.object) == "string" then entry.id = cmd.object end
    h.objects[#h.objects + 1] = entry
  end
end

local function ensure_dir(path)
  local lfs = require("lfs")
  if not lfs.attributes(path, "mode") then lfs.mkdir(path) end
end

-- Hospitals whose expert issued a game command since the last learning
-- save (watch_commands): index -> true.
local acted = {}

--! Save the game for learning (why: "year 2", "end"), if an expert plays
--! and did something since the last save.
local function learn_save(why, lobby)
  local world = TheApp.world
  if not learning or not world then return end
  note_bots(world)
  local playing = experts_playing(world)
  if not next(playing) then return end
  -- Only the experts who did something since the last save (or the start):
  -- a game continued from a save and only looked at teaches nothing new
  -- (Argus on 2026-11-15: three saves loaded, nothing built, all "learnt").
  local idle = {}
  for index, name in pairs(playing) do
    if not acted[index] then
      playing[index] = nil
      idle[#idle + 1] = name
    end
  end
  table.sort(idle)
  if not next(playing) then
    log(string.format("learning: no save (%s): %s did nothing since the last save", why, table.concat(idle, ", ")))
    return
  end
  acted = {}
  local ok, err = pcall(function()
    ensure_dir(learn_dir)
    ensure_dir(learn_dir .. "/saves")
    local date = world:date()
    local name = string.format("%s %s y%d-%02d-%02d", os.date("!%Y%m%d-%H%M%S"),
        room:gsub("[^%w%-_ ']", "_"), date:year(), date:monthOfYear(), date:dayOfMonth())
    local path = learn_dir .. "/saves/" .. name
    local session = TheApp.mp_session
    if session and session.withoutBlueprints then
      session:withoutBlueprints(function() TheApp:save(path .. ".sav") end)
    else
      TheApp:save(path .. ".sav")
    end
    local hospitals = {}
    for index, hospital in ipairs(world.hospitals) do
      local entry = {index = index, name = tostring(hospital.name),
          expert = playing[index] ~= nil, bot_ever = bot_ever[index] or false}
      -- (An expert's hospital: who is the expert, and who built what in it.)
      if players_hospital(hospital) and experts_in(hospital)[1] then
        entry.experts = experts_in(hospital)
        entry.built = built[index] or {rooms = {}, objects = {}}
      end
      hospitals[#hospitals + 1] = entry
    end
    local f = assert(io.open(path .. ".json", "w"))
    f:write(json_text({room = room, why = why, date = date:tostring(), step = session and session.step or 0,
        level = level_name(world), build = lobby and lobby.build or "",
        hospitals = hospitals}), "\n")
    f:close()
    local names = {}
    for _, n in pairs(playing) do names[#names + 1] = n end
    table.sort(names)
    log(string.format("learning: saved %s.sav (%s; %s)", name, why, table.concat(names, ", ")))
  end)
  if not ok then log("learning: could not save: " .. tostring(err)) end
end

-- What the experts build, as it happens in the game (the commands that ran),
-- one JSON line each: for the order they build in.
local BUILD_KINDS = {"build_room", "room_object", "room_finish", "room_edit", "room_pickup", "room_buy",
    "room_delete", "room_unbuild", "room_rebuild", "place_object", "move_object", "sell_object", "buy_plot"}
local function watch_builds()
  corsixth.require("mp_session")
  local handlers = MultiplayerSession.default_handlers
  for _, kind in ipairs(BUILD_KINDS) do
    local handler = handlers[kind]
    if handler then
      handlers[kind] = function(world, cmd)
        local ok, why = handler(world, cmd)
        pcall(function()
          local index = tonumber(cmd.hospital) or 1
          local hospital = world.hospitals[index]
          local name = hospital and tostring(hospital.name):upper()
          note_bots(world)
          if not name or bot_ever[index] or not players_hospital(hospital) or not experts_in(hospital)[1] then
            return
          end
          -- (Everyone's building in a hospital an expert shares: whose is whose.)
          if ok then note_builder(index, kind, cmd) end
          local by = sender(cmd)
          ensure_dir(learn_dir)
          ensure_dir(learn_dir .. "/builds")
          local f = io.open(learn_dir .. "/builds/" .. room:gsub("[^%w%-_]", "_") .. ".jsonl", "a")
          if not f then return end
          local fields = {}
          for k, v in pairs(cmd) do
            if type(v) == "string" or type(v) == "number" then fields[k] = v end
          end
          f:write(json_text({date = world:date():tostring(), hospital = index, name = name, kind = kind,
              by = by, by_expert = by and experts[by] and true or false,
              ok = ok and true or false, why = why and tostring(why) or nil, cmd = fields}), "\n")
          f:close()
        end)
        return ok, why
      end
    end
  end
end

-- Commands that do not count as doing something in one's hospital: the
-- shared speed, saving, being away, and what the game does by itself.
local IDLE_KINDS = {set_speed = true, speed_vote = true, speed_vote_answer = true, save_game = true,
    player_away = true, hold_done = true, room_takeover = true}

--! Note which hospitals act (acted): every command that ran for one, but
--! IDLE_KINDS, and not an assistant's (a bot's) in an expert's hospital.
local function watch_commands()
  corsixth.require("mp_session")
  local handlers = MultiplayerSession.default_handlers
  local kinds = {}
  for kind in pairs(handlers) do kinds[#kinds + 1] = kind end
  for _, kind in ipairs(kinds) do
    local handler = handlers[kind]
    if not IDLE_KINDS[kind] and type(handler) == "function" then
      handlers[kind] = function(world, cmd)
        local ok, why = handler(world, cmd)
        if ok then
          local by = sender(cmd)
          if by == nil or experts[by] then acted[tonumber(cmd.hospital) or 1] = true end
        end
        return ok, why
      end
    end
  end
end

local function run()
  assert(loadfile(source_dir .. "/CorsixTH/CorsixTH.lua"))(unpack_args(args))
  assert(TheApp.good_install_folder, "Game data was not accepted")
  local socket = require("socket")
  corsixth.require("mp_lobby")

  local lobby, err = MultiplayerLobby.connect(server, "referee", 10,
      {role = "referee", room = room, token = token})
  assert(lobby, "cannot connect: " .. tostring(err))
  lobby.log = log
  the_lobby = lobby
  log("connected as " .. lobby.build)
  if learning then
    local names = {}
    for n in pairs(experts) do names[#names + 1] = n end
    table.sort(names)
    log("learning from " .. table.concat(names, ", ") .. " into " .. learn_dir)
    watch_builds()
    watch_commands()
  end

  -- Wait for the server's START (the game data and level load here).
  local deadline = socket.gettime() + 30
  while lobby.state ~= "in_game" do
    lobby:poll()
    if lobby.state == "closed" then error("server closed the connection: " ..
        tostring(lobby.error and lobby.error.text)) end
    if socket.gettime() > deadline then error("no START from the server") end
    socket.sleep(0.01)
  end
  log("game started")
  -- Tests only: the probes set up their hospitals the same way on every
  -- peer before the first step; the referee must do it too.
  local probe_spec = os.getenv("MP_REFEREE_PROBE_SCENARIO") -- "room=scenario;..."
  -- (A continued game has no world until its save arrives, and was set up
  -- before it was saved.)
  if probe_spec and TheApp.world then
    local probe_scenario = "light"
    for r, sc in probe_spec:gmatch("([^;=]+)=([^;]+)") do
      if r == room then probe_scenario = sc end
    end
    local builder = assert(loadfile(source_dir .. "/scripts/multiplayer/probe_builder.lua"))()
    if probe_scenario == "none" then
      builder.register_handlers() -- (as lobby_probe.lua does: no setup, test commands only)
    else
      builder.start_game(TheApp.world, TheApp.mp_session, probe_scenario, log)
    end
    log("probe setup: " .. probe_scenario)
  end

  local last_report = socket.gettime()
  local last_year
  while lobby.state == "in_game" and not lobby.transport.closed do
    local session = TheApp.mp_session
    if not session then break end
    -- A continued game: no world until the host's save arrives (the session
    -- is held until then); App:onTick reads the network and loads it.
    if not TheApp.world and not session.held then break end
    -- Always run as fast as the lockstep allows; the players set the pace.
    if TheApp.world and not TheApp.world:isCurrentSpeed("And then some more") and not session.held then
      TheApp.world:setSpeed("And then some more")
    end
    local before = session.step
    TheApp:onTick()
    -- The annual report window would pause this game; close it at once.
    local report = TheApp.world and TheApp.ui:getWindow(UIAnnualReport)
    if report then report:close() end
    if session.step == before then socket.sleep(0.002) end
    -- A new game year: the year that ended, saved for learning.
    if learning and TheApp.world and session.step ~= before then
      local year = TheApp.world:date():year()
      if last_year and year > last_year then learn_save("year " .. last_year, lobby) end
      if session.step % 100 == 0 then note_bots(TheApp.world) end
      last_year = year
    end
    if socket.gettime() - last_report > 60 then
      last_report = socket.gettime()
      log("at step " .. session.step)
    end
  end
  log("game over (" .. tostring(lobby.state) .. ")")
  if learning then learn_save("end", lobby) end
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  io.stderr:flush()
  os.exit(1)
end
os.exit(0)
