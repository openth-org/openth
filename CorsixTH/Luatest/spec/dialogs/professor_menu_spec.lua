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

-- The professor's main menu (the original game's, Jan 2026-11-22): where its
-- picture goes on screens of any shape, and which spot of the chart is where.
describe("Professor menu", function()
  setup(function()
    require("corsixth")
    require("class_test_base")
    require("TH")
    require("utility")
    require("window")
    require("dialogs.resizable")
    require("dialogs.resizables.main_menu")
    require("dialogs.resizables.professor_menu")
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

  it("keeps to the right of a wider screen, with the fill at its left", function()
    for _, size in ipairs({{2560, 1080}, {3440, 1440}, {3840, 1600}, {5120, 1440}}) do
      local w, h = size[1], size[2]
      local l = UIProfessorMenu.layout(w, h)
      local f = l.scale
      local what = ("%dx%d"):format(w, h)
      -- No black at the right; at most a picture pixel of his back cut off.
      assert.is_true(l.x + 320 * f >= w - 0.001 and l.x + 320 * f < w + f, what .. " right")
      -- The fill reaches the screen's left edge (up to 32:9).
      assert.is_true(l.px > 0 and l.px <= UIProfessorMenu.SIDE_W, what .. " fill")
    end
  end)

  it("fills the side from the chart and the blackboard, not the professor", function()
    for y = 0, 199 do
      for x = -UIProfessorMenu.SIDE_W, -1 do
        local c = UIProfessorMenu.sideColumn(x, y)
        local what = ("%d,%d from %s"):format(x, y, tostring(c))
        assert.is_true(c >= 0 and c < 320 and c == math.floor(c), what)
        -- Below the blackboard's frame he is from column 203 on.
        assert.is_true(y <= 24 or c <= 202, what)
        -- The chart's left end (22 columns) is made from the chart.
        if x >= -22 and y >= 5 and y <= 159 then assert.is_true(c <= 177, what) end
      end
    end
    -- The skeleton's other half: its arm, the mirror image of the one there.
    assert.equal(31, UIProfessorMenu.sideColumn(-1, 90))
    assert.equal(38, UIProfessorMenu.sideColumn(-8, 90))
  end)

  it("fills beside his movies with the chart as they have it", function()
    for y = 0, 199 do
      for x = -UIProfessorMenu.SIDE_W, -1 do
        local up = UIProfessorMenu.sideColumn(x, y, "up")
        local gone = UIProfessorMenu.sideColumn(x, y, "gone")
        local what = ("%d,%d: %s %s"):format(x, y, tostring(up), tostring(gone))
        -- Rolled up, the blackboard is behind the chart (below the roller).
        if x >= -22 and y > 21 and y < 192 then assert.is_true(up >= 180 and up <= 200, what) end
        -- Gone, nothing of the roller is left (its mount from column 186 on).
        if y <= 24 then assert.is_true(gone >= 186, what) end
        assert.is_true(y <= 24 or y >= 192 or gone <= 202, what)
      end
    end
    local at = UIProfessorMenu.chartInMovie
    assert.equal(23, at(false, 0))
    assert.equal(120, at(false, 8000))
    assert.equal(159, at(false, 20000))
    assert.equal(159, at(true, 0))
    assert.equal(23, at(true, 1800))
    assert.is_false(at(true, 2500))
    local light = UIProfessorMenu.lightInMovie
    assert.is_nil(light(false, 5000))
    assert.same({97, 91}, {light(false, 10300)})
    assert.is_nil(light(false, 13000))
    assert.is_nil(light(true, 1000))
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

  it("writes and takes the chalk where no spot is", function()
    -- (Argus: what he writes clear of the small skull, the Settings spot.)
    for _, rect in ipairs({UIProfessorMenu.TEXT, UIProfessorMenu.WRITING, UIProfessorMenu.CHALK}) do
      for y = rect[2], rect[2] + rect[4] - 1 do
        for x = rect[1], rect[1] + rect[3] - 1 do
          local spot = UIProfessorMenu.spotAtPicture(x + 0.5, y + 0.5)
          assert.is_nil(spot, ("%d,%d is on %s"):format(x, y, spot and spot.item or ""))
        end
      end
    end
    -- He writes on the chart, between the big skull and its red edge, under
    -- the small skull; the chalk is on the blackboard under the chart.
    local text = UIProfessorMenu.TEXT
    assert.is_true(text[1] >= 122 and text[1] + text[3] <= 172 and text[2] >= 64)
    assert.is_true(UIProfessorMenu.CHALK[2] >= 160 and UIProfessorMenu.CHALK[2] + UIProfessorMenu.CHALK[4] <= 182)
  end)

  it("decodes his arm's pictures as the engine does", function()
    local decode = UIProfessorMenu.decodeChunks
    local function bytes(...) return string.char(...) end
    -- 4 wide, 3 high: two colours, the end of the line, a gap of two, five
    -- of one colour (0x41: 65 - 60), and the end of the line.
    local data = bytes(0x02, 7, 8, 0x00, 0x82, 0x41, 9, 0x00)
    local pixels = decode(data, 1, #data, 4, 3)
    assert.same({[0] = 7, [1] = 8, [6] = 9, [7] = 9, [8] = 9, [9] = 9, [10] = 9}, pixels)
    -- An end of line right after a full line does not skip the next one;
    -- colour 255 is transparent (0xFF: a count and a colour).
    data = bytes(0x02, 1, 2, 0x00, 0x01, 3, 0xFF, 1, 255, 0x01, 4)
    assert.same({[0] = 1, [1] = 2, [2] = 3, [4] = 4}, decode(data, 1, #data, 2, 3))
    -- From the middle of a sheet's data: only the given bytes.
    data = bytes(0x01, 5, 0x01, 6, 0x01, 7)
    assert.same({[0] = 6}, decode(data, 3, 4, 3, 1))
  end)
end)
