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

-- The professor's main menu (the original game's, Jan 2026-11-22): where its
-- picture goes on screens of any shape, and which spot of the chart is where.
describe("Professor menu", function()
  setup(function()
    require("corsixth")
    require("class_test_base")
    require("TH")
    require("utility")
    require("window")
    require("dialogs/resizable")
    require("dialogs/resizables/main_menu")
    require("dialogs/resizables/professor_menu")
  end)

  local SIZES = {{640, 480}, {800, 600}, {1024, 768}, {1280, 720}, {1280, 800},
    {1366, 768}, {1920, 1080}, {1920, 1200}, {2560, 1080}, {3440, 1440},
    {3840, 2160}, {1080, 1920}}

  it("fills the screen, keeping the chart and the professor's face", function()
    for _, size in ipairs(SIZES) do
      local w, h = size[1], size[2]
      local l = UIProfessorMenu.layout(w, h)
      local f = l.scale
      local what = ("%dx%d"):format(w, h)
      assert.equal(l.px * f, l.x, what)
      assert.equal(l.py * f, l.y, what)
      -- The chart's left edge and the professor's face (x 0 to 300) on the
      -- screen, as are the rows from the roller to under the chart (2 to 182),
      -- give or take the corner's rounding to a whole picture pixel.
      assert.is_true(l.x >= -f / 2 - 0.001 and l.x + 300 * f <= w + f / 2 + 0.001, what .. " across")
      assert.is_true(l.y + 2 * f >= -f / 2 - 0.001 and l.y + 182 * f <= h + f / 2 + 0.001, what .. " down")
      -- No more black than the shape needs: the picture reaches two opposite
      -- edges.
      local across = l.x <= f and l.x + 320 * f >= w - f
      local down = l.y <= f and l.y + 200 * f >= h - f
      assert.is_true(across or down, what .. " has black on all sides")
    end
    -- On the common screens the whole screen is the picture.
    for _, size in ipairs({{1920, 1080}, {1280, 720}, {1280, 800}, {3840, 2160}}) do
      local l = UIProfessorMenu.layout(size[1], size[2])
      assert.is_true(l.x <= 0 and l.y <= 0 and l.x + 320 * l.scale >= size[1] and
          l.y + 200 * l.scale >= size[2], ("%dx%d"):format(size[1], size[2]))
    end
  end)

  it("finds each spot inside its own outline, and none elsewhere", function()
    for _, spot in ipairs(UIProfessorMenu.SPOTS) do
      local sx, sy, n = 0, 0, 0
      for i = 1, #spot.outline - 1, 2 do
        sx, sy, n = sx + spot.outline[i], sy + spot.outline[i + 1], n + 1
      end
      assert.equal(spot, UIProfessorMenu.spotAtPicture(sx / n, sy / n), spot.item)
    end
    -- The professor, the blackboard, the chart's writing and its blank paper.
    for _, point in ipairs({{250, 100}, {200, 180}, {145, 90}, {140, 140}, {40, 20}}) do
      assert.is_nil(UIProfessorMenu.spotAtPicture(point[1], point[2]),
          ("%d,%d"):format(point[1], point[2]))
    end
    -- The middle of the skull's X is Exit, between its eyes Multiplayer.
    assert.equal("exit", UIProfessorMenu.spotAtPicture(82, 135).item)
    assert.equal("multiplayer", UIProfessorMenu.spotAtPicture(84, 90).item)
  end)

  it("has a spot for every item of the list menu, each once", function()
    local seen = {}
    for _, spot in ipairs(UIProfessorMenu.SPOTS) do
      assert.is_nil(seen[spot.item], spot.item)
      seen[spot.item] = true
      assert.is_function(UIMainMenu[spot.button], spot.button)
    end
    for _, item in ipairs({"new_game", "custom_campaign", "custom_level", "multiplayer",
        "continue", "load_game", "options", "map_edit", "exit", "discord"}) do
      assert.is_true(seen[item], item)
    end
  end)
end)
