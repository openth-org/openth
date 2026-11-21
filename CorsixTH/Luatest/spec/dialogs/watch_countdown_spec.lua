--[[ Copyright (c) 2026 CorsixTH-Multiplayer contributors

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

-- The countdown watch made after a multiplayer load (a repair, a rejoin) at
-- some point of the countdown looks as one that counted down to it (Argus
-- and Jan, 2026-11-21: only the two hands showed, the red segments not).
describe("Countdown watch", function()
  setup(function()
    -- (The game's own, from app.lua; specs run without it.)
    math.round = math.round or function(input) return math.floor(input + 0.5) end
    require("corsixth")
    require("class_test_base")
    require("TH")
    require("utility")
    require("date")
    require("window")
    require("dialogs/watch")
  end)

  local function make()
    TheApp.gfx.loadSpriteTable = function() return {} end
    local ui = {app = TheApp, hospital = {}}
    return UIWatch(ui, "initial_opening")
  end

  --! The watch's picture: its panels' sprites, in order.
  local function picture(watch)
    local sprites = {}
    for i, panel in ipairs(watch.panels) do sprites[i] = panel.sprite_index end
    return sprites
  end

  --! A watch counted down here to `open_timer`, as onWorldTick does.
  local function counted(open_timer)
    local watch = make()
    while watch.open_timer > open_timer do
      watch.open_timer = watch.open_timer - 1
      watch:_showOpenTimer()
    end
    return watch
  end

  it("looks the same set straight to a point of the countdown", function()
    for _, at in ipairs({12, 11, 9, 6, 5, 4, 1, 0}) do
      local watch = make()
      assert.is_true(watch:mpSetCountdown({tick_rate = 7, tick_timer = 3, open_timer = at}))
      assert.same(picture(counted(at)), picture(watch), "open_timer " .. at)
      assert.equal(at, watch.open_timer)
      assert.equal(3, watch.tick_timer)
      assert.equal(7, watch.tick_rate)
    end
  end)

  it("goes on from where it is, and cannot go back", function()
    local watch = make()
    watch:mpSetCountdown({tick_rate = 7, tick_timer = 0, open_timer = 8})
    assert.is_true(watch:mpSetCountdown({tick_rate = 7, tick_timer = 2, open_timer = 3}))
    assert.same(picture(counted(3)), picture(watch))
    assert.is_false(watch:mpSetCountdown({tick_rate = 7, tick_timer = 2, open_timer = 6}))
  end)
end)
