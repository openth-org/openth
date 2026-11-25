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

require("corsixth")
require("class_test_base")
if not Window then class "Window" end
require("dialogs.jukebox")

-- The jukebox lists its tracks in one column while they fit on the screen,
-- else in more columns side by side (Jan, 2026-11-24: with the new songs the
-- list ran off the screen).
describe("Jukebox layout", function()
  -- Rows the first column holds (the others one more) and the window's
  -- height, 74 + 30 * rows + 18 (UIJukebox:UIJukebox).
  local function check(count, screen_w, screen_h)
    local columns, rows = UIJukebox.layout(count, screen_w, screen_h)
    local holds = rows + (columns - 1) * (rows + 1)
    assert.is_true(holds >= count, "all tracks have a place")
    assert.is_true(holds - count < columns, "no column left empty")
    return columns, rows, 74 + 30 * rows + 18
  end

  it("keeps the original single column while the tracks fit", function()
    local columns, rows = check(23, 1920, 1080)
    assert.equal(1, columns)
    assert.equal(23, rows)
  end)

  it("uses more columns when the tracks would run off the screen", function()
    -- 42 tracks: 1,350 pixels in one column. (960 x 540: 1920 x 1080 at UI
    -- scale 2.)
    for _, size in ipairs({{1920, 1080}, {1024, 768}, {800, 600}, {960, 540}}) do
      local w, h = size[1], size[2]
      local columns, _, height = check(42, w, h)
      assert.is_true(columns > 1, "columns at " .. w .. "x" .. h)
      assert.is_true(height <= h, "fits in " .. w .. "x" .. h .. " (" .. height .. " high)")
      assert.is_true(columns * 259 <= w, "fits in " .. w .. "x" .. h .. " (" .. columns .. " columns)")
    end
  end)

  it("spreads the tracks evenly over the columns", function()
    -- 1080 high: 31 rows fit; 42 tracks in two columns of 21 and 22.
    local columns, rows = check(42, 1920, 1080)
    assert.equal(2, columns)
    assert.equal(21, rows)
    -- 800 x 600: 15 rows fit, three columns of 14 and 15.
    columns, rows = check(42, 800, 600)
    assert.equal(3, columns)
    assert.equal(14, rows)
  end)

  it("never uses more columns than the screen is wide", function()
    -- 640 x 480 holds two columns; the rest runs below the screen.
    local columns = check(42, 640, 480)
    assert.equal(2, columns)
  end)
end)
