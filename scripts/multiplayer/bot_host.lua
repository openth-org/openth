-- One game for all the computer players (bots) of a multiplayer room.
--
-- The server (mp_server) starts it when the first bot is added to a room
-- that has not started yet:
--   corsix-th --interpreter=<this file> --config-file=<generated>
-- and writes every bot of the room (the first one too) as a line into the
-- control file MP_HOST_CONTROL, which this game reads every half second:
--   ADD token=<token> name=<name> level=<easy|normal|hard>
--
-- Before, each bot was a whole game of its own: seven bots and the referee
-- were eight copies of the same game on the server (eu1, two cores, was at
-- twice what it could do, 2026-11-28). Now the bots of a room share one.
--
-- How:
-- * Each bot keeps a connection of its own, as if it ran alone: the server
--   takes a player's moves and step reports only from that player's own
--   connection, and keeps its place, chat, level and advice per connection.
-- * Each bot keeps its own mind: bot.lua is loaded once per bot (its name,
--   its random numbers, its plans, its manager and builder are its own).
-- * There is one game: the bot with the lowest place number (the leader)
--   starts it from its START; the others' START is only noted. The game's
--   session reads every connection (Host.receive): a move or step report of
--   one of these bots is dropped (this game made it, or runs the same steps),
--   everything else comes in once, from the leader's connection. The others'
--   lines are kept for a while: every connection gets the same lines in the
--   same order (bar each bot's own), so when the leader leaves the game (a
--   person takes its place) the next bot carries on exactly where it stopped.
-- * After each step the game sends its step report for every bot, each on
--   its own connection (the same fingerprint: the same game).
-- * A bot's turn (its update every tick, the game's news it hears) runs in
--   its own place of the game: its hospital is the game's own hospital
--   (world.ui.hospital), its place number the session's, its moves go out on
--   its connection, and the room it is furnishing has the room editor.
-- * When the server holds the game to repair it, every connection answers
--   HELD; only the leader's connection loads the repaired game.
--
-- Bots added to a game already running (a bot for a place somebody left)
-- still run as a game of their own (bot.lua alone).
--
-- Environment (set by the server): CORSIXTH_SOURCE, MP_SERVER, MP_BOT_ROOM,
-- MP_HOST_CONTROL, MP_BOT_MODE, MP_LUA_CPATH, MP_LUA_PATH, and the tests'
-- settings of bot.lua (MP_BOT_FAST, MP_BOT_TESTS, ...), the same for every bot.
local args = {...}
local unpack_args = table.unpack or unpack
local source_dir = assert(os.getenv("CORSIXTH_SOURCE"), "Missing CORSIXTH_SOURCE")
local server = assert(os.getenv("MP_SERVER"), "Missing MP_SERVER")
local room = assert(os.getenv("MP_BOT_ROOM"), "Missing MP_BOT_ROOM")
local control_path = assert(os.getenv("MP_HOST_CONTROL"), "Missing MP_HOST_CONTROL")
local fast = os.getenv("MP_BOT_FAST") == "1"

if os.getenv("MP_LUA_CPATH") then package.cpath = os.getenv("MP_LUA_CPATH") .. ";" .. package.cpath end
if os.getenv("MP_LUA_PATH") then package.path = os.getenv("MP_LUA_PATH") .. ";" .. package.path end

local function log(msg)
  io.stdout:write("[host] " .. msg .. "\n")
  io.stdout:flush()
end

-- Lines of the game (moves, step reports) each bot that is not the leader
-- keeps, for a change of leader. (The connections differ by a few
-- milliseconds at most.)
local KEEP_LINES = 4096
-- Once the first bot's game has started, how long the others' START may take
-- (seconds); a bot without one is not in the game.
local START_WAIT = 3

local socket, room_builder
-- Every bot, in the order the server added it: {name, token, chunk (its
-- bot.lua), lobby (its connection), start, peer, bot, gone, lines, count}.
local members = {}
-- The bot whose connection runs the game.
local leader
-- Place number -> member, for the bots in the game.
local owned = {}
-- What the game's session reads next (Host.receive).
local queue, queue_first, queue_last = {}, 1, 0
-- Game lines handed to the session, counted the same way on every
-- connection (member.count).
local delivered = 0
-- The connection the bot whose turn it is sends on (nil: the leader's).
local actor
-- A bot's place left the game (LEFT) before its connection was the leader's.
local left_seen = {}

--------------------------------------------------------------------------------
-- The bots the server adds
--------------------------------------------------------------------------------

local control_offset = 0
--! New whole lines of the control file.
local function control_lines()
  local f = io.open(control_path, "rb")
  if not f then return {} end
  f:seek("set", control_offset)
  local data = f:read("*a") or ""
  f:close()
  local last = data:match(".*()\n")
  if not last then return {} end
  control_offset = control_offset + last
  local lines = {}
  for line in data:sub(1, last):gmatch("[^\r\n]+") do lines[#lines + 1] = line end
  return lines
end

local function add_member(f)
  for _, m in ipairs(members) do
    if m.token == f.token then return end
  end
  local loaded, chunk = pcall(function()
    return assert(loadfile(source_dir .. "/scripts/multiplayer/bot.lua"))({env = {
      MP_BOT_TOKEN = f.token, MP_BOT_NAME = f.name, MP_BOT_LEVEL = f.level or "normal", MP_BOT_STANDIN = "0"}})
  end)
  if not loaded then
    log("cannot load " .. tostring(f.name) .. ": " .. tostring(chunk))
    return
  end
  local lobby, err = MultiplayerLobby.connect(server, f.name, 10, {role = "bot", room = room, token = f.token})
  if not lobby then
    chunk.log("cannot connect: " .. tostring(err))
    return
  end
  lobby.log = chunk.log
  local m = {name = f.name, token = f.token, chunk = chunk, lobby = lobby, lines = {}, count = 0}
  -- Its START is only noted: the leader's is the game.
  lobby._onSTART = function(self, sf)
    self.start_params = sf
    self.state = "in_game"
    m.start = sf
  end
  members[#members + 1] = m
  chunk.log("connected as " .. tostring(lobby.build) .. " (one game for the room's bots)")
end

local function read_control()
  for _, line in ipairs(control_lines()) do
    local verb, f = MultiplayerLobby.decode(line)
    if verb == "ADD" and f.token and f.name then
      if leader then
        log("ignored (the game has started): " .. tostring(f.name))
      else
        add_member(f)
      end
    end
  end
end

local function live()
  local n = 0
  for _, m in ipairs(members) do
    if not m.gone then n = n + 1 end
  end
  return n
end

--------------------------------------------------------------------------------
-- A bot's turn: its place of the game
--------------------------------------------------------------------------------

--! The hospital index of a member (the leader's lobby knows the places).
local function index_of(m)
  local places = leader and leader.lobby.peer_hospital
  return places and places[m.peer] or m.index or 1
end

--! A room this place is furnishing or editing by hand (its room editor).
local function own_entry(world, peer)
  local best, best_id
  for id, entry in pairs(world.mp_furnishing or {}) do
    if entry.peer == peer and not entry.unbuilt and (not best_id or id < best_id) then
      best, best_id = entry, id
    end
  end
  return best
end

--! Run fn() as member m's game: its hospital, its place, its connection
--! (full: also the room editor it is working with). Returns pcall's results.
local function as_member(m, fn, full)
  local session, world = TheApp.mp_session, TheApp.world
  if m == leader or not session or not world or not world.ui then return pcall(fn) end
  local ui = world.ui
  local index = index_of(m)
  local hospital = world.hospitals[index]
  if not hospital then return pcall(fn) end
  local saved = {hospital = ui.hospital, local_index = world.mp_local_index, peer = session.peer_id,
      index = session.hospital_index, edit_room = ui.edit_room, hit_test = ui.do_world_hit_test,
      cursor = ui.cursor}
  local base_entry, own
  if full then
    -- The leader's room editor makes way for this bot's.
    base_entry = own_entry(world, saved.peer)
    if base_entry and ui.edit_room == base_entry.dlg then
      room_builder.hide(world, base_entry)
    else
      base_entry = nil
    end
    ui.edit_room = false
  end
  ui.hospital, world.mp_local_index = hospital, index
  session.peer_id, session.hospital_index = m.peer, index
  actor = m.lobby.transport
  if full then
    own = own_entry(world, m.peer)
    if own then
      room_builder.show(world, own)
    elseif m.edit_tool then
      ui.edit_room = true
    end
  end
  local results = {pcall(fn)}
  if full then
    m.edit_tool = ui.edit_room == true or nil
    if own then room_builder.hide(world, own) end
    ui.edit_room = saved.edit_room
    ui.do_world_hit_test = saved.hit_test
    if saved.cursor and ui.cursor ~= saved.cursor then ui:setCursor(saved.cursor) end
  end
  ui.hospital, world.mp_local_index = saved.hospital, saved.local_index
  session.peer_id, session.hospital_index = saved.peer, saved.index
  actor = nil
  if base_entry then room_builder.show(world, base_entry) end
  return unpack_args(results)
end

--! Every bot hears what the game does (bot.lua install_hooks), each in its
--! own place.
local function each(method, ...)
  local n, params = select("#", ...), {...}
  for _, m in ipairs(members) do
    if m.bot and not m.gone then
      local ok, err = as_member(m, function() return m.bot[method](m.bot, unpack_args(params, 1, n)) end)
      if not ok then m.chunk.log("ERROR in " .. method .. ": " .. tostring(err)) end
    end
  end
end

--------------------------------------------------------------------------------
-- The connections and the game's session
--------------------------------------------------------------------------------

--! The session's transport: moves go out on the connection of the bot whose
--! turn it is; lines come in from all of them (pump).
local Host = {closed = false}

function Host:send(line)
  (actor or leader.lobby.transport):send(line)
end

function Host:receive()
  if queue_first > queue_last then
    queue, queue_first, queue_last = {}, 1, 0
    return nil
  end
  local line = queue[queue_first]
  queue[queue_first] = nil
  queue_first = queue_first + 1
  return line
end

function Host:close() end

local function deliver(line)
  queue_last = queue_last + 1
  queue[queue_last] = line
end

--! The place number of a move ("C ... peer=n ...") or step report ("S n ...").
local function line_peer(line)
  if line:sub(1, 2) == "S " then return tonumber(line:match("^S (%d+) ")) end
  return tonumber(line:match(" peer=(%d+)"))
end

--! A line one of the bots' connections received.
local function route(m, line)
  local head = line:sub(1, 2)
  if head == "C " or head == "S " then
    -- After a shared save (LOAD ... RESUME) the server sends the moves made
    -- after it again, these bots' own too (loading the save forgot them):
    -- the leader's copy goes in whole; nothing of it is counted, so the
    -- connections' game lines stay alike for a change of leader.
    if m.replay then
      if m == leader then deliver(line) end
      return
    end
    -- One of these bots' own: made in this game (pending since issued), or
    -- a report of the steps this game runs.
    if owned[line_peer(line)] then return end
    m.count = m.count + 1
    if m == leader then
      if m.count > delivered then
        delivered = m.count
        deliver(line)
      end
    else
      m.lines[m.count] = line
      m.lines[m.count - KEEP_LINES] = nil
    end
    return
  end
  -- The server's messages: the leader's go to the game (in order with the
  -- moves: a repair's save, then the moves after it); each other bot's to its
  -- own lobby (chat, advice, the player list), where those about the game
  -- itself do nothing (it is not the session's lobby).
  local verb = line:match("^(%u+)")
  if verb == "LOAD" then
    m.replay = true
  elseif verb == "RESUME" then
    m.replay = nil
  end
  if m == leader then
    deliver(line)
    return
  end
  local f
  verb, f = MultiplayerLobby.decode(line)
  if verb == "HOLD" then
    -- The server waits for every player to stop.
    local session = TheApp.mp_session
    if session and not session.held then
      session.held = true
      session.repair_why = f.why or "desync"
    end
    m.lobby:send("HELD", {step = session and session.step or 0})
    return
  end
  if verb == "LEFT" and f.peer then
    left_seen[tonumber(f.peer)] = f
  end
  m.lobby:handleLine(line)
end

local function member_gone(m, why)
  if m.gone then return end
  m.gone = true
  -- (Its place is somebody else's from now on: a person who took it, or a
  -- bot playing for them.)
  if m.peer and owned[m.peer] == m then owned[m.peer] = nil end
  m.chunk.log("left the shared game (" .. tostring(why) .. ")")
end

local next_leader
--! Read every connection: the leader's first, so that if it has left (a
--! person took its place, which also reloads the game) the next bot takes
--! over before the reload on its own connection is read.
local function pump()
  local order = {leader}
  for _, m in ipairs(members) do
    if m ~= leader then order[#order + 1] = m end
  end
  for _, m in ipairs(order) do
    if not m.gone then
      local transport = m.lobby.transport
      while true do
        local line = transport:receive()
        if not line then break end
        local ok, err = pcall(route, m, line)
        if not ok then m.chunk.log("ERROR reading a line: " .. tostring(err)) end
      end
      if transport.closed or m.lobby.state == "closed" then member_gone(m, "connection closed") end
    end
    if leader.gone and not next_leader() then return end
  end
end

--! The lobby fields the game set on the leader's lobby that the bots read
--! from their own (places, names).
local function share_places()
  local from = leader.lobby
  for _, m in ipairs(members) do
    if m ~= leader and not m.gone then
      m.lobby.peer_hospital = from.peer_hospital
      m.lobby.peer_names = from.peer_names
      m.lobby.start_peers = from.start_peers
      if m.lobby.start_params and from.start_params then m.lobby.start_params.mode = from.start_params.mode end
    end
  end
end

--! The game's session: these bots' places are this game's own.
local function own_places(session)
  local places = {}
  for peer, m in pairs(owned) do
    if not m.gone then places[peer] = true end
  end
  for peer in pairs(places) do
    if peer ~= session.peer_id then
      session.peer_step[peer] = nil
      for _, fps in pairs(session.peer_fps) do fps[peer] = nil end
    end
  end
end

local wrapped = setmetatable({}, {__mode = "k"})
local function take_session(session)
  if wrapped[session] then return end
  wrapped[session] = true
  session.transport = Host
  -- Speed votes are for the people (MultiplayerSession:voterCount).
  session.abstains = true
  local after_step = session.afterStep
  session.afterStep = function(s, unchanged)
    after_step(s, unchanged)
    for peer, m in pairs(owned) do
      if m ~= leader and not m.gone then
        m.lobby.transport:send(string.format("S %d %d %s", peer, s.step, tostring(s.last_fp)))
      end
    end
  end
  local restart_at = session.restartAt
  session.restartAt = function(s, ...)
    restart_at(s, ...)
    own_places(s)
  end
  own_places(session)
end

--! The session speaks through `lobby` (as MultiplayerLobby:_beginGame set
--! it up for the first leader): its messages, log, notices, outlines,
--! player names and desync reports.
local function bind_session(session, lobby)
  session.lobby = lobby
  session.control = function(line) lobby:handleLine(line) end
  session.log = function(msg) lobby.log("multiplayer: " .. msg) end
  session.notify = function(msg)
    lobby.log("multiplayer: notice: " .. tostring(msg))
    local ui = TheApp.ui
    if TheApp.world and ui and ui.adviser then ui.adviser:say({text = msg, priority = 10}) end
  end
  session.send_cosmetic = function(fields) lobby:send("SHOW", fields) end
  session.peer_name = function(p)
    local pl = lobby.players and lobby.players[p]
    return pl and pl.name
  end
  session.send_diagnostics = function(step, text)
    for i = 1, #text, 3000 do
      lobby:send("DIAG", {step = step, part = math.floor(i / 3000) + 1, text = text:sub(i, i + 2999)})
    end
  end
end

--! The leader left the game (a person took its place): the bot with the next
--! lowest place carries on from the last line the game had.
function next_leader()
  local best
  for peer, m in pairs(owned) do
    if not m.gone and (not best or peer < best.peer) then best = m end
  end
  if not best then return false end
  local old = leader
  leader = best
  for i = delivered + 1, best.count do
    local line = best.lines[i]
    if not line then
      log("WARNING: game lines lost at the change of leader (" .. i .. ")")
      break
    end
    deliver(line)
  end
  delivered = math.max(delivered, best.count)
  best.lines = {}
  local session = TheApp.mp_session
  local from, to = old.lobby, best.lobby
  to.saved_config, to.restore_order = from.saved_config, from.restore_order
  to.game_players = to.game_players or from.game_players
  to.peer_hospital, to.peer_names, to.start_peers = from.peer_hospital, from.peer_names, from.start_peers
  to.shared_speed = from.shared_speed
  if session then
    bind_session(session, to)
    session.peer_id = best.peer
    session.hospital_index = index_of(best)
    local world = TheApp.world
    if world and world.ui then
      world.ui.hospital = world.hospitals[session.hospital_index] or world.ui.hospital
      world.mp_local_index = session.hospital_index
    end
    own_places(session)
    local left = left_seen[old.peer]
    if left then session:removePeer(old.peer, left.replaced == "1", left.name) end
  end
  if old.bot then old.bot.closes_windows = false end
  if best.bot then best.bot.closes_windows = true end
  best.chunk.log("now runs the shared game (" .. old.name .. " left it)")
  return true
end

--------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------

local function begin_game()
  local started = {}
  for _, m in ipairs(members) do
    if not m.gone and m.start then
      m.peer = tonumber(m.start.peer)
      started[#started + 1] = m
    end
  end
  table.sort(started, function(a, b) return a.peer < b.peer end)
  leader = started[1]
  for _, m in ipairs(members) do
    if not m.gone and not m.start then
      m.chunk.log("not in the game (no START): leaves")
      m.lobby:disconnect()
      m.gone = true
    end
  end
  for _, m in ipairs(started) do owned[m.peer] = m end
  -- The leader's lobby starts the game (MultiplayerLobby:_beginGame).
  MultiplayerLobby._onSTART(leader.lobby, leader.start)
  local session = TheApp.mp_session
  if not session or session.lobby ~= leader.lobby then
    error("the game did not start: " .. tostring(leader.lobby.error and leader.lobby.error.text))
  end
  take_session(session)
  share_places()
  for _, m in ipairs(started) do
    m.index = index_of(m)
    local ok, bot = as_member(m, function() return m.chunk.new(m.lobby) end)
    if ok then
      m.bot = bot
      bot.closes_windows = m == leader
    else
      m.chunk.log("ERROR: could not start: " .. tostring(bot))
    end
  end
  local names = {}
  for _, m in ipairs(started) do names[#names + 1] = m.name .. " (" .. m.peer .. ")" end
  log("game started for " .. table.concat(names, ", ") .. "; " .. leader.name .. " runs it")
end

local function run()
  assert(loadfile(source_dir .. "/CorsixTH/CorsixTH.lua"))(unpack_args(args))
  assert(TheApp.good_install_folder, "Game data was not accepted")
  socket = require("socket")
  corsixth.require("mp_lobby")
  corsixth.require("mp_session")
  room_builder = corsixth.require("mp_room_builder")

  -- The bots of the room.
  local deadline = socket.gettime() + 60
  while #members == 0 do
    read_control()
    if #members == 0 then
      if socket.gettime() > deadline then error("no bot in " .. control_path) end
      socket.sleep(0.2)
    end
  end
  members[1].chunk.install_hooks(each)
  if os.getenv("MP_BOT_TESTS") == "1" then members[1].chunk.builder.register_handlers() end
  -- A room an exploding machine destroyed, cleared to be built again
  -- (repair=1): the game then issues the new room for the player who asked,
  -- if that is this game's own place (handlers.remove_crashed_room); for the
  -- other bots of this game it is done here the same way.
  local handlers = MultiplayerSession.default_handlers
  local remove_crashed = handlers.remove_crashed_room
  if remove_crashed then
    handlers.remove_crashed_room = function(world, cmd)
      local m = owned[tonumber(cmd.peer)]
      local repair
      if m and m ~= leader and not m.gone and tonumber(cmd.repair) == 1 then
        local crashed = world.rooms[tonumber(cmd.room)]
        repair = crashed and crashed.crashed and room_builder.repairCommand(world, crashed)
      end
      local ok, why = remove_crashed(world, cmd)
      local session = TheApp.mp_session
      if ok and repair and session then
        repair.hospital = tonumber(cmd.hospital) or index_of(m)
        local issued, err = as_member(m, function() session:issue(repair) end)
        if not issued then m.chunk.log("ERROR: the room's repair: " .. tostring(err)) end
      end
      return ok, why
    end
  end
  -- The game ends for everybody (lost, or all back to the lobby): stop.
  local finished = false
  MultiplayerSession.finishGame = function(self)
    self.finish_request = nil
    finished = true
  end

  -- The room waits: more bots may come, some may go.
  local next_read, first_start = 0, nil
  while true do
    local now = socket.gettime()
    if now >= next_read then
      read_control()
      next_read = now + 0.5
    end
    for _, m in ipairs(members) do
      if not m.gone then
        m.lobby:poll()
        if m.lobby.state == "closed" and not m.start then
          member_gone(m, tostring(m.lobby.error and m.lobby.error.text or "closed"))
        end
        if m.start and not first_start then first_start = now end
      end
    end
    if live() == 0 then
      log("no bot left in the room")
      return
    end
    if first_start then
      local waiting = false
      for _, m in ipairs(members) do
        if not m.gone and not m.start then waiting = true end
      end
      if not waiting or now - first_start > START_WAIT then break end
    end
    socket.sleep(0.05)
  end
  begin_game()

  local next_tick
  while not finished do
    pump()
    if leader.gone and not next_leader() then break end
    local session = TheApp.mp_session
    if not session then break end
    if not TheApp.world and not session.held then break end
    take_session(session)
    local before = session.step
    if fast then
      -- Tests: one step per tick, as fast as the others allow.
      session.unpaced, session.steps_per_tick = true, 1
    else
      -- One tick every 18 ms, like the game's own timer.
      local now = socket.gettime()
      if next_tick and now < next_tick then socket.sleep(next_tick - now) end
      next_tick = math.max(now, next_tick or now) + 0.018
    end
    TheApp:onTick()
    share_places()
    for _, m in ipairs(members) do
      if m.bot and not m.gone then
        local ok, err = as_member(m, function() m.bot:update() end, true)
        if not ok then m.chunk.log("ERROR: " .. tostring(err)) end
      end
    end
    if fast and session.step == before then socket.sleep(0.002) end
  end
  log("game over")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  io.stderr:flush()
  os.exit(1)
end
os.exit(0)
