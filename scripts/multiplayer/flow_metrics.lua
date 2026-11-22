-- How well patients get from room to room in a hospital (Argus, 2026-11-22,
-- roadmap "Recommendations for bots on hospital planning": the heart of a
-- hospital is its corridors; rooms must not wall each other off). Walks are
-- the game's own (World:getPathDistance), so a detour around the building
-- counts in full.
--   metric1  the average walk between the doors of two of its rooms (the
--            tile just outside each door, every pair of rooms)
--   metric2  for each room the longest walk between two of the free corridor
--            tiles around it, averaged over the rooms
--   blocked  pairs of doors at most 12 tiles apart (along x and y) whose walk
--            is three times that or more: one room walls off another
-- Lower is better. On "Mount Everest" (2026-11-21, game date 2-08-10) Argus's
-- hospital had 30 and 9, Bertie's and Agnes's 91-98 and 23-26.
--   local Flow = dofile("scripts/multiplayer/flow_metrics.lua")
--   local m = Flow.measure(world, hospital)
local Flow = {}

Flow.NEAR = 12      -- doors this near (along x and y) ...
Flow.DETOUR = 3     -- ... with a walk this many times as long count as blocked
Flow.SAMPLE = 24    -- free tiles around a room measured at most

--! The hospital's rooms in use that have a door, in a fixed order.
function Flow.rooms(world, hospital)
  local out = {}
  for _, room in pairs(world.rooms) do
    if room.hospital == hospital and room.door and room.door.tile_x and room.is_active and not room.crashed then
      out[#out + 1] = room
    end
  end
  table.sort(out, function(a, b) return a.y * 1000 + a.x < b.y * 1000 + b.x end)
  return out
end

--! The free corridor tiles around a room: walkable, in the building, of this
--! hospital's plots, in no room.
function Flow.tilesAround(world, hospital, room)
  local th = world.map.th
  local flags = {}
  local owner = hospital:getPlayerIndex()
  local out = {}
  local function try(x, y)
    if not world:isOnMap(x, y) then return end
    th:getCellFlags(x, y, flags)
    if flags.passable and flags.hospital and world:getRoom(x, y) == nil and (flags.parcelId or 0) ~= 0
        and th:getPlotOwner(flags.parcelId) == owner then
      out[#out + 1] = {x, y}
    end
  end
  for x = room.x - 1, room.x + room.width do
    try(x, room.y - 1)
    try(x, room.y + room.height)
  end
  for y = room.y, room.y + room.height - 1 do
    try(room.x - 1, y)
    try(room.x + room.width, y)
  end
  return out
end

--! The metrics of one hospital: {rooms, metric1, metric2, blocked = {{a, b,
--! walk, apart}...} (worst first), around = {{room, walk}...} (worst first),
--! unreachable (door pairs with no walk)}.
function Flow.measure(world, hospital)
  local rooms = Flow.rooms(world, hospital)
  local doors = {}
  for i, room in ipairs(rooms) do
    local x, y = room:getEntranceXY(false)
    doors[i] = {x = x, y = y, room = room}
  end
  local sum, n, unreachable, blocked = 0, 0, 0, {}
  for i = 1, #doors do
    for j = i + 1, #doors do
      local a, b = doors[i], doors[j]
      local d = world:getPathDistance(a.x, a.y, b.x, b.y)
      local apart = math.abs(a.x - b.x) + math.abs(a.y - b.y)
      if d and d > 0 then
        sum, n = sum + d, n + 1
        if apart <= Flow.NEAR and d >= Flow.DETOUR * math.max(apart, 2) then
          blocked[#blocked + 1] = {a = a.room, b = b.room, walk = d, apart = apart}
        end
      elseif apart > 0 then
        unreachable = unreachable + 1
      end
    end
  end
  local sum2, n2, around = 0, 0, {}
  for _, room in ipairs(rooms) do
    local tiles = Flow.tilesAround(world, hospital, room)
    if #tiles > Flow.SAMPLE then
      local picked, step = {}, #tiles / Flow.SAMPLE
      for k = 0, Flow.SAMPLE - 1 do picked[#picked + 1] = tiles[math.floor(k * step) + 1] end
      tiles = picked
    end
    local longest = 0
    for i = 1, #tiles do
      for j = i + 1, #tiles do
        local d = world:getPathDistance(tiles[i][1], tiles[i][2], tiles[j][1], tiles[j][2])
        if d and d > longest then longest = d end
      end
    end
    if #tiles >= 2 then
      sum2, n2 = sum2 + longest, n2 + 1
      around[#around + 1] = {room = room, walk = longest}
    end
  end
  table.sort(blocked, function(p, q)
    return p.walk - Flow.DETOUR * p.apart > q.walk - Flow.DETOUR * q.apart
  end)
  table.sort(around, function(p, q) return p.walk > q.walk end)
  return {rooms = #rooms, metric1 = n > 0 and sum / n or 0, metric2 = n2 > 0 and sum2 / n2 or 0,
      blocked = blocked, around = around, unreachable = unreachable}
end

--! A room as text: "research@45,181".
function Flow.roomText(room)
  return string.format("%s@%d,%d", room.room_info.id, room.x, room.y)
end

--! One line per hospital with rooms, and its worst blocked pair and room.
function Flow.lines(world)
  local out = {}
  for index, hospital in ipairs(world.hospitals) do
    local m = Flow.measure(world, hospital)
    if m.rooms > 0 then
      local worst = m.blocked[1]
      local around = m.around[1]
      out[#out + 1] = string.format("flow %d %s: rooms=%d metric1=%.1f metric2=%.1f blocked=%d unreachable=%d%s%s",
          index, tostring(hospital.name), m.rooms, m.metric1, m.metric2, #m.blocked, m.unreachable,
          worst and string.format(" worst=%s->%s:%d/%d", Flow.roomText(worst.a), Flow.roomText(worst.b),
              worst.walk, worst.apart) or "",
          around and string.format(" around=%s:%d", Flow.roomText(around.room), around.walk) or "")
    end
  end
  return out
end

return Flow
