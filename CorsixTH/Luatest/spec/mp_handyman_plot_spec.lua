--[[ Copyright (c) 2026 OpenTH contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. --]]

-- Argus's game on MOUNT EVEREST (2026-11-23): an evil handyman given one of
-- the victim's plots was thrown out; at home that plot was not his hospital's
-- land, the idle tile search wants both, found nothing, and the meander
-- started another meander at once, without end: a stack overflow stopped
-- every game in the room. Every hospital's list of plots also held plot 1
-- (hospital 1's), so one press of the plot button did the same.

require("corsixth")
require("class_test_base")
require("date")
require("mp_session")
require("humanoid_action")
require("entity")
require("entities.humanoid")
require("entities.humanoids.staff.handyman")

local MultiplayerSession = _G["MultiplayerSession"]
local handlers = MultiplayerSession.default_handlers

-- Four plots: 1 is player 1's, 2 and 3 player 2's, 4 nobody's.
local OWNERS = {1, 2, 2, 0}

local function hospital(index, plots)
  return {player_index = index, ownedPlots = plots, is_in_world = true,
      getPlayerIndex = function(self) return self.player_index end}
end

local function world_with(hospitals, entities)
  local th = {
    getPlotCount = function() return #OWNERS end,
    getPlotOwner = function(_, plot) return OWNERS[plot] end,
  }
  local world = {map = {th = th}, hospitals = hospitals, entities = entities or {}}
  function world.getEntityById(_, id)
    for _, e in ipairs(world.entities) do
      if e.mp_id == id then return e end
    end
  end
  return world
end

local function handyman(id, home, plot)
  return setmetatable({mp_id = id, hospital = home, parcelNr = plot}, {__index = Handyman})
end

describe("Multiplayer handymen's plots", function()
  it("lists only the plots a hospital's player owns", function()
    local h1, h2 = hospital(1, {1}), hospital(2, {1})
    local world = world_with({h1, h2})
    assert.same({1}, MultiplayerSession.ownedPlots(world, h1))
    assert.same({2, 3}, MultiplayerSession.ownedPlots(world, h2))
  end)

  it("puts a loaded game's lists right and frees handymen of other land", function()
    local h1, h2 = hospital(1, {1}), hospital(2, {1, 3})
    local theirs, own = handyman(7, h2, 1), handyman(8, h2, 3)
    local world = world_with({h1, h2}, {theirs, own})
    MultiplayerSession.checkPlots(world)
    assert.same({1}, h1.ownedPlots)
    assert.same({3, 2}, h2.ownedPlots) -- (its own order kept, the missing one after)
    assert.equal(0, theirs.parcelNr)
    assert.equal(3, own.parcelNr)
    -- A game that is right already stays as it is (a repair loads it on some
    -- peers only).
    MultiplayerSession.checkPlots(world)
    assert.same({3, 2}, h2.ownedPlots)
    assert.equal(3, own.parcelNr)
  end)

  it("refuses a plot of another hospital for a handyman", function()
    local h1, h2 = hospital(1, {1}), hospital(2, {1, 2, 3})
    local man = handyman(9, h2, 0)
    local world = world_with({h1, h2}, {man})
    local ok, why = handlers.handyman_parcel(world, {hospital = 2, staff = 9, parcel = 1})
    assert.is_false(ok)
    assert.equal("not our plot", why)
    assert.equal(0, man.parcelNr)
    assert.is_false((handlers.handyman_parcel(world, {hospital = 2, staff = 9, parcel = 4})))
    assert.is_true(handlers.handyman_parcel(world, {hospital = 2, staff = 9, parcel = 3}))
    assert.equal(3, man.parcelNr)
  end)

  it("lets a handyman who moves to another hospital look after all its land", function()
    local h1, h2 = hospital(1, {1}), hospital(2, {2, 3})
    local man = Handyman({setHitTestResult = function() end})
    man.updateDynamicInfo = function() end
    man:setHospital(h2)
    man.parcelNr = 3
    man:setHospital(h2) -- (the same hospital: kept)
    assert.equal(3, man.parcelNr)
    man:setHospital(h1)
    assert.equal(0, man.parcelNr)
  end)
end)

-- The meander's start handler on a humanoid whose queue works like the real
-- one: finishing an action starts the next, a meander by this handler.
describe("A handyman with no task and nowhere to walk", function()
  local meander_start = require("humanoid_actions.meander")
  local saved = {}

  before_each(function()
    saved.IdleAction = _G.IdleAction
    _G.IdleAction = setmetatable({}, {__call = function()
      local idle = {name = "idle"}
      function idle.setCount(self, n) self.count = n return self end
      return idle
    end})
  end)

  after_each(function()
    _G.IdleAction = saved.IdleAction
  end)

  local function stuck_handyman()
    local starts = 0
    local man = setmetatable({tile_x = 5, tile_y = 5, parcelNr = 1, last_room = nil}, {__index = Handyman})
    man.world = {pathfinder = {findIdleTile = function() return nil end}}
    man.action_queue = {{name = "meander"}}
    function man.getRoom() return nil end
    function man.isIdle() return true end
    function man.getCurrentAction(self) return self.action_queue[1] end
    -- As Handyman:doMeandering does when he is not meandering yet: one more.
    function man.searchForHandymanTask(self)
      local q = self.action_queue
      if not (#q >= 2 and (q[1].name == "idle" or q[1].name == "walk") and q[2].name == "meander") then
        q[#q + 1] = {name = "meander"}
      end
      return false
    end
    function man.queueAction(self, action, pos)
      if pos then table.insert(self.action_queue, pos + 1, action) else self.action_queue[#self.action_queue + 1] = action end
    end
    function man.finishAction(self)
      table.remove(self.action_queue, 1)
      local head = self.action_queue[1]
      if head and head.name == "meander" then
        starts = starts + 1
        assert(starts < 50, "the next meander started at once, again and again")
        meander_start(head, self)
      end
    end
    return man
  end

  it("waits a moment before the next meander instead of starting it at once", function()
    local man = stuck_handyman()
    meander_start(man.action_queue[1], man)
    assert.equal("idle", man.action_queue[1].name)
    assert.equal(20, man.action_queue[1].count)
    assert.equal("meander", man.action_queue[2].name)
    assert.equal(2, #man.action_queue)
  end)
end)
