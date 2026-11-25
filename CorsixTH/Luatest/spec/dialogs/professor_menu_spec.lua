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
    -- His feet are whole: beside them no mirrored toe, only paper.
    for x = -12, -1 do assert.equal(42, UIProfessorMenu.sideColumn(x, 144)) end
  end)

  it("turns the chart's left end into its right end's mirror image gradually", function()
    local blend = UIProfessorMenu.endBlend
    -- At the picture's edge only what goes on from it, at the chart's edge
    -- (the right end's red line and on) only the mirror image.
    for x = -6, -1 do assert.equal(0, blend(x)) end
    for x = -UIProfessorMenu.SIDE_W, -17 do assert.equal(1, blend(x)) end
    local last = 0
    for x = -7, -16, -1 do
      local w = blend(x)
      assert.is_true(w > last and w < 1, ("%d: %s"):format(x, w))
      last = w
    end
    -- The bottom line thins first, from the picture's edge, before the
    -- bottom edge darkens.
    for _, y in ipairs({155, 156}) do
      assert.equal(0, blend(-1, y))
      assert.is_true(blend(-6, y) > 0 and blend(-6, y) < 1)
      for x = -16, -12 do assert.equal(1, blend(x, y)) end
    end
    assert.equal(0, blend(-6, 159))
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
    -- (Each frame's row as measured again on 2026-11-24.)
    local at = UIProfessorMenu.chartInMovie
    assert.equal(21, at(false, 0))
    assert.equal(121, at(false, 8000))
    -- Springing back, a fraction of a row a frame: up three rows and down
    -- again (measured to a tenth of a row on 2026-11-25).
    assert.equal(158.3, at(false, 8286))
    assert.equal(158.1, at(false, 8357))
    assert.equal(156.1, at(false, 10000))
    assert.equal(158.1, at(false, 11071))
    assert.equal(158.2, at(false, 11143))
    assert.equal(158.8, at(false, 11857))
    assert.equal(159, at(false, 11929))
    assert.equal(159, at(false, 20000))
    local spring = UIProfessorMenu.MOVIE_CHART.coming
    for i = 3, #spring - 1, 2 do
      if spring[i] > 8143 then assert.is_true(math.abs(spring[i + 1] - spring[i - 1]) <= 0.5, spring[i]) end
    end
    assert.equal(159, at(true, 0))
    assert.equal(170, at(true, 1550))
    -- Rolling, an edge between two rows at the picture's edge, as there.
    assert.equal(48.7, at(false, 7786))
    assert.equal(111.5, at(true, 1643))
    assert.equal(21, at(true, 1800))
    assert.is_false(at(true, 2500))
    -- What the movies show behind and under the chart: rolled up as he
    -- comes, the board while it rolls, then nothing more; the board while it
    -- rolls up, wound up, springing up and gone as he leaves.
    local look = UIProfessorMenu.lookInMovie
    assert.equal("up", look(false, 0))
    assert.equal("board", look(false, 8000))
    assert.is_nil(look(false, 8200))
    assert.is_nil(look(true, 0))
    assert.equal("board", look(true, 1700))
    assert.equal("rolled", look(true, 1800))
    -- (For a frame the roller springs up off its mount, the frame under it.)
    assert.equal("sprung", look(true, 1857))
    assert.equal("rolled_high", look(true, 1950))
    assert.equal("gone", look(true, 2500))
    -- Row by row, from the picture's edge to the chart's end.
    for name, rows in pairs(UIProfessorMenu.MOVIE_ROWS) do
      assert.equal(#rows.left, #rows.right, name)
      for i, colour in ipairs(rows.left) do
        assert.equal(3, #colour, name)
        assert.equal(3, #rows.right[i], name)
      end
      assert.is_true(rows.from + #rows.left <= 192 and rows.reach < 0, name)
      -- The board's light: a row and a percent each, the rows in order.
      assert.equal(0, #rows.board % 2, name)
      for i = 3, #rows.board - 1, 2 do assert.is_true(rows.board[i] > rows.board[i - 2], name) end
    end
    local light = UIProfessorMenu.lightInMovie
    assert.is_nil(light(false, 5000))
    assert.same({99, 93}, {light(false, 10300)})
    assert.is_nil(light(false, 13000))
    assert.same({101, 102}, {light(true, 1000)})
    assert.is_nil(light(true, 2500))
    -- The blackboard's light while the chart is down: darker and lighter as
    -- he turns, as the picture's once he stands still.
    local board = UIProfessorMenu.boardInMovie
    assert.equal(100, board(false, 5000))
    assert.equal(72, board(false, 8500))
    assert.equal(124, board(false, 10200))
    assert.equal(100, board(false, 13000))
    assert.equal(124, board(true, 100))
    assert.equal(100, board(true, 2500))
    for _, movie in ipairs({"coming", "leaving"}) do
      local keys = UIProfessorMenu.MOVIE_BOARD[movie]
      assert.equal(0, #keys % 2, movie)
      for i = 3, #keys - 1, 2 do assert.is_true(keys[i] > keys[i - 2], movie) end
    end
  end)

  it("takes the fill beside the picture's edge from his movie's frame while the chart is down", function()
    local strip = UIProfessorMenu.movieStrip
    assert.same({}, strip(nil))
    assert.same({}, strip(121))
    assert.same({}, strip(21))
    for _, bottom in ipairs({159, 156.1, 164}) do
      local seen = {}
      for _, d in ipairs(strip(bottom)) do
        assert.equal(d.sh, d.h)
        assert.equal(d.sy, d.y)
        assert.is_true(d.sx >= 0 and d.sx + d.sw <= 43, "only the frame's first columns")
        assert.is_true(d.flip or d.sw == 1)
        for x = d.x, d.x + d.w - 1 do
          -- The frame's column for the fill's column x, as drawn.
          local col = d.sw == 1 and d.sx or d.sx + (d.x + d.w - 1 - x)
          for y = d.y, d.y + d.h - 1 do
            local key = x .. "," .. y
            assert.is_nil(seen[key], key)
            seen[key] = true
            -- At the picture's rows, the column the fill takes from the
            -- picture (his feet: only paper beside them).
            if bottom == 159 then
              assert.equal(UIProfessorMenu.sideColumn(x, y, "down"), col, key)
            end
          end
          local blend = UIProfessorMenu.endBlend(x)
          assert.equal(math.floor(255 * (1 - blend) + 0.5), d.alpha, x)
          assert.is_true(d.alpha > 0)
        end
      end
      for x = -16, -1 do
        for y = 0, 199 do assert.is_true(seen[x .. "," .. y], x .. "," .. y .. " at " .. bottom) end
      end
    end
    -- Springing back, the paper beside his feet starts higher, as the frame
    -- has it.
    local function feet(bottom)
      for _, d in ipairs(strip(bottom)) do
        if d.sx == 42 and d.w == 6 and d.x == -6 then return d.y end
      end
    end
    assert.equal(141, feet(159))
    assert.is_true(feet(156.1) < 141)
  end)

  it("makes beforehand every fill drawn beside his movies", function()
    local fills = UIProfessorMenu.movieFills()
    local key = UIProfessorMenu.fillKey
    local made = {}
    for _, f in ipairs(fills) do
      local k = key(f[1], f[2], f[3], f[4])
      assert.is_nil(made[k], k)
      made[k] = true
    end
    -- The first needed first: rolled up as he comes, then as he pulls the
    -- chart down; the roller springing up as he leaves.
    assert.equal("up/up", key(fills[1][1], fills[1][2], fills[1][3], fills[1][4]))
    assert.equal("up/board", key(fills[2][1], fills[2][2], fills[2][3], fills[2][4]))
    assert.is_true(made["up/sprung"])
    assert.is_true(made["down"], "the menu's own")
    -- Drawing each frame of both movies, and the menu, asks for none but
    -- those.
    local asked = {}
    local bitmap = {draw = function() end}
    local loaded = {picture = bitmap, sides = setmetatable({}, {__index = function(_, k)
      asked[k] = true
      return bitmap
    end})}
    local canvas = {getRenderSize = function() return 2560, 1080 end, scale = function() return true end,
      pushClip = function() end, popClip = function() end}
    local art, app = UIProfessorMenu.art, _G["TheApp"]
    UIProfessorMenu.art = function() return loaded end
    _G["TheApp"] = {config = {}}
    local ok, err = pcall(function()
      for _, leaving in ipairs({false, true}) do
        for n = 0, 200 do
          local pts = UIProfessorMenu.frameTime(n)
          local top, low = UIProfessorMenu.lightInMovie(leaving, pts)
          UIProfessorMenu.drawSide(canvas, UIProfessorMenu.chartInMovie(leaving, pts), top, low,
              UIProfessorMenu.lookInMovie(leaving, pts), UIProfessorMenu.boardInMovie(leaving, pts))
        end
      end
      UIProfessorMenu.drawPicture(canvas)
    end)
    UIProfessorMenu.art, _G["TheApp"] = art, app
    assert(ok, err)
    for k in pairs(asked) do assert.is_true(made[k], k) end
    for k in pairs(made) do assert.is_true(asked[k], k) end
  end)

  it("draws the fill beside his movies for the frame they show", function()
    local frame, time = UIProfessorMenu.movieFrame, UIProfessorMenu.frameTime
    -- The engine's time of a frame (frame 111: 111 times 0.07142 seconds),
    -- and the movie's clock between two frames.
    assert.equal(0, frame(0))
    assert.equal(111, frame(111 * 0.07142 * 1000))
    assert.equal(111, frame(7990))
    assert.equal(111, frame(7999))
    assert.equal(112, frame(112 * 71.42))
    assert.equal(112, frame(8000))
    assert.equal(7929, time(111))
    -- Every time in the movie tables is a frame's.
    for name, step in pairs({MOVIE_CHART = 2, MOVIE_LOOK = 2, MOVIE_BOARD = 2, MOVIE_LIGHT = 3}) do
      for movie, keys in pairs(UIProfessorMenu[name]) do
        for i = 1, #keys, step do
          assert.equal(keys[i], time(math.floor(keys[i] * 14 / 1000 + 0.5)), name .. " " .. movie)
        end
      end
    end

    package.loaded["sdl"] = package.loaded["sdl"] or {getTicks = function() return 0 end}
    require("movie_player")
    local movie = setmetatable({}, {__index = _G["MoviePlayer"]})
    movie.playMovie = function(self) self.playing = true end
    local drawSide, drawn = UIProfessorMenu.drawSide, nil
    UIProfessorMenu.drawSide = function(_, bottom) drawn = bottom end
    local ok, err = pcall(function()
      local at = UIProfessorMenu.chartInMovie
      -- The engine says which frame it drew: the fill is that frame's, however
      -- far ahead the clock is (the pictures came late).
      movie:playMenuMovie(false)
      movie.refresh_overlay(movie, 0, 0, 320, 200, 1, 8600, 110 * 71.42)
      assert.equal(at(false, time(110)), drawn)
      assert.equal(71.6, drawn)
      -- An engine that does not say shows the next frame once the clock
      -- reaches it, one frame a refresh; the clock going back (with the sound
      -- on) does not take the frame back.
      movie:playMenuMovie(false)
      movie.refresh_overlay(movie, 0, 0, 320, 200, 1, 8000)
      assert.equal(at(false, time(1)), drawn)
      for _ = 1, 200 do movie.refresh_overlay(movie, 0, 0, 320, 200, 1, 8000) end
      assert.equal(121, drawn)
      movie.refresh_overlay(movie, 0, 0, 320, 200, 1, 7000)
      assert.equal(121, drawn)
    end)
    UIProfessorMenu.drawSide = drawSide
    assert(ok, err)
  end)

  it("moves the chart's left end as his movies move the chart", function()
    local row = UIProfessorMenu.chartRow
    -- Rolling down or up, the whole chart is higher, under the roller's
    -- shadow on its paper (which stays).
    for y = 22, 29 do assert.equal(y, row(y, 120)) end
    for y = 30, 120 do assert.equal(y + 39, row(y, 120)) end
    -- Springing back, its top stays and its paper is squeezed: each row one
    -- of the chart's, in order, down to its bottom edge.
    for _, bottom in ipairs({156, 157, 158}) do
      for y = 22, 80 do assert.equal(y, row(y, bottom)) end
      assert.equal(159, row(bottom, bottom))
      for y = 81, bottom do
        local r = row(y, bottom)
        assert.is_true(r > row(y - 1, bottom) and r - y <= 159 - bottom, ("%d at %d"):format(y, bottom))
      end
    end
    -- (Or as a fraction: the paper squeezed evenly to a bottom edge between
    -- two rows.)
    assert.equal(80, row(80, 156.5, true))
    assert.near(159, row(156.5, 156.5, true), 1e-9)
    assert.near(80 + 40 * 79 / 76.5, row(120, 156.5, true), 1e-9)
    for y = 22, 159 do assert.equal(y, row(y, 159)) end
    -- Tugged, its paper is pulled lower, its top stays and the paper
    -- between is drawn out.
    for y = 22, 32 do assert.equal(y, row(y, 164)) end
    for y = 33, 37 do assert.equal(32, row(y, 164)) end
    for y = 38, 164 do assert.equal(y - 5, row(y, 164)) end
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
