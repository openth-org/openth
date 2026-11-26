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

-- The professor's menu is a kind of the list menu: it has the same buttons,
-- and what looks for the main menu finds it too.
local UIMainMenu = cth_require("dialogs.resizables.main_menu")
local TH = require("TH")

--! The original game's main menu: the professor at his blackboard, pointing
--! at the parts of the skull on his chart (QData Main01M, a 320x200 picture,
--! and Main02M, his arm pointing at each part, which turns pink). The menu
--! items the original did not have are on the skeleton beside the skull and
--! on the small skull, which turn pink the same way. The name of the item
--! pointed at, and what it does, are written on the chart in place of its
--! own writing. The picture is the menu's background (UI:setMenuBackground),
--! so it stays behind the windows the menu opens; this window draws the
--! picture with what is pointed at, made once for each item, and on the
--! blackboard under the chart, in chalk, the question that opens the tips.
class "UIProfessorMenu" (UIMainMenu)

---@class UIProfessorMenu: UIMainMenu
---@operator call: UIProfessorMenu
local UIProfessorMenu = _G["UIProfessorMenu"] ---@type UIProfessorMenu

-- The tips window opens when asked for (Argus), not with the menu (app.lua).
UIProfessorMenu.tips_when_asked = true

-- The picture's size.
local PIC_W, PIC_H = 320, 200
-- What stays on the screen when the picture is scaled to fill it: all but
-- the professor's back and the edges of the wall above and below.
local KEEP_W, KEEP_TOP, KEEP_BOTTOM = 300, 2, 182
-- On a screen wider than the picture, the picture keeps to the right (the
-- screen's edge cuts the professor's back, as the original's did) and what
-- is left of it at the left is filled (as much as a 32:9 screen needs), from
-- the picture itself: the chart's left end and the blackboard beside it.
local SIDE_W = 320
-- The chart's paper ends at CHART_RIGHT; its left end is at CHART_LEFT (on
-- the fill), as wide as the right end's edge and red line (EDGE_W). The
-- skeleton (rows SKELETON_TOP to SKELETON_BOTTOM) has its middle at half
-- SKELETON_2X; past its other half the paper is PAPER_COLUMN's. His feet
-- (from SKELETON_FEET) are whole in the picture: only paper beside them. The
-- paper's colour beside it is found in the picture's first EDGE_PAPER columns
-- (the paper beyond the skeleton has other blotches).
local CHART_RIGHT, CHART_LEFT, EDGE_W = 177, -22, 6
-- The right end yellows, its bottom edge darkens and the roller's top drops a
-- row over its last columns, so from BLEND_FROM to the edge the left end goes
-- over from what goes on from the picture's edge to the right end's mirror
-- image little by little (UIProfessorMenu.endBlend). The chart's bottom line
-- (rows LINE_TOP and LINE_LOW) is two rows thick on its left and one on its
-- right: it thins first, from the picture's edge (to LINE_TO), so that the
-- paper under it keeps its width where the bottom edge darkens. Of the right
-- end's paper between the roller's shadow and the bottom line (rows
-- END_PAPER_TOP to END_PAPER_LOW) only the paper is taken, not what is drawn
-- on it (the back of the side skull's head).
local BLEND_FROM = -6
local LINE_TOP, LINE_LOW, LINE_TO = 155, 156, -11
local END_PAPER_TOP, END_PAPER_LOW = 23, 154
local SKELETON_2X, SKELETON_TOP, SKELETON_BOTTOM, SKELETON_FEET = 30, 31, 151, 141
local PAPER_COLUMN, EDGE_PAPER = 42, 12
-- Beside the chart's right end, clear of the professor: the roller's end, its
-- cap and mount (to MOUNT_TO), the frame above the blackboard (down to
-- FRAME_BOTTOM, from FRAME_FROM to the picture's edge), the blackboard
-- (BOARD_FROM to BOARD_TO) and the ledge under it (from LEDGE_TOP).
local MOUNT_TO, FRAME_FROM, FRAME_BOTTOM = 202, 196, 24
local BOARD_FROM, BOARD_TO, LEDGE_TOP = 180, 200, 192
-- The roller (down to ROLLER_BOTTOM, its end cap to MOUNT_FROM, where its
-- mount starts) and the chart's bottom edge (CHART_BOTTOM) when it is down.
local ROLLER_BOTTOM, MOUNT_FROM, CHART_BOTTOM = 21, 186, 159
-- In his movies the chart is down (not rolling) with its bottom edge from
-- DOWN_FROM on. Springing back after he pulls it down, it is squeezed from
-- STRETCH_FROM down (above it the chart stays where it is); when he tugs at
-- it as he leaves, the paper from PULL_FROM down is pulled lower and its row
-- PULL_FROM drawn out over the gap. The roller's shadow on the paper (to
-- ROLLER_SHADOW) stays where it is while the chart rolls.
local DOWN_FROM, STRETCH_FROM, PULL_FROM, ROLLER_SHADOW = CHART_BOTTOM - 9, 80, 32, 29
-- (Springing back, the blackboard under its bottom edge moves up with it, to
-- UNDER_EDGE rows below where the edge is when it is down.)
local UNDER_EDGE = 4

--! How far apart (milliseconds) the frames of his movies are: 71.42, as their
--! Smacker headers say. (The times in the MOVIE_ tables below are those of
--! frames 1000/14 milliseconds apart, rounded, as they were measured.)
UIProfessorMenu.MOVIE_FRAME_MS = 71.42

--! The frame of one of his movies that shows from `pts` (milliseconds, the
--! frame's own time or the movie's clock) on: its number, from 0.
function UIProfessorMenu.movieFrame(pts)
  return math.floor(pts / UIProfessorMenu.MOVIE_FRAME_MS + 1e-6)
end

--! The time of frame `frame` of one of his movies as the MOVIE_ tables have
--! it (milliseconds).
function UIProfessorMenu.frameTime(frame)
  return math.floor(frame * 1000 / 14 + 0.5)
end

--! Where the chart's bottom edge is in his movies, as they go on: the time
--! of the frame (in milliseconds, 14 frames a second) and the row from that
--! frame on (ROLLER_BOTTOM: rolled up under its roller; false: the chart and
--! its roller have fallen off), measured on the movies' frames. Coming (ANIMS
--! MMENU1), the chart is rolled up until he pulls it down at 7.7 seconds; it
--! springs back a little and settles. Leaving (MMENU2), he tugs at it, lets it
--! roll up at 1.6 seconds and pulls it off its mount at 2.
--! (Each frame's bottom row checked again on 2026-11-24, as the row above the
--! board under it at three places along the chart's left part: several
--! changes had come a frame or three late, and Jan saw the chart's left end
--! jump as it settled.)
--! Springing back, it moves up three rows and down again a tenth of a row or
--! so a frame: there the rows are fractions, the edge where it is between
--! two rows of the picture (measured on 2026-11-25 at six times the size,
--! the fill's edge against the movie's on either side of the picture's edge,
--! in tenths of a row; whole rows held the fill still while the movie moved
--! on, then made it jump: Jan saw the left side lag as the chart went up).
--! Rolling, some frames have its edge between two rows at the picture's edge
--! (half lit): there too a fraction, fitted to the edge as the movie has it
--! at the picture's first columns (2026-11-25: a row higher than the movie's
--! at the seam as he pulled it down and let it roll up).
UIProfessorMenu.MOVIE_CHART = {
  coming = {0, ROLLER_BOTTOM, 7714, 36, 7786, 48.7, 7857, 71.6, 7929, 86, 8000, 121,
    8071, 145.2, 8143, 158.4, 8214, 158.3, 8357, 158.1, 8429, 157.9, 8500, 157.8,
    8571, 157.7, 8643, 157.6, 8786, 157.5, 8929, 157.4, 9000, 157.3, 9071, 157.2,
    9214, 157.1, 9286, 156.9, 9357, 156.8, 9571, 156.7, 9643, 156.5, 9786, 156.3,
    9929, 156.2, 10000, 156.1, 10357, 156.2, 10429, 156.4, 10500, 156.6, 10571, 156.9,
    10643, 157, 10714, 157.1, 10786, 157.3, 10857, 157.5, 10929, 157.9, 11071, 158.1,
    11143, 158.2, 11286, 158.4, 11429, 158.6, 11571, 158.7, 11786, 158.8, 11929, 159},
  leaving = {0, 159, 1429, 164, 1500, 170, 1571, 159, 1643, 111.5, 1714, 48.4,
    1786, ROLLER_BOTTOM, 2000, false},
}

--! What his movies show behind and under the chart where the picture has
--! nothing like it, row by row from row `from`, from column `reach` of the
--! fill to the picture's edge: at the picture's left edge (`left`) and at
--! the chart's right end (`right`; its left end on the fill is its mirror
--! image, UIProfessorMenu.endBlend between). Rolled up as he comes (`up`):
--! the paper's edge in the roller's shadow, the blackboard's frame behind
--! the chart and the frame's shadow on the board; rolled up as he leaves
--! (`rolled`, then `sprung` as the roller springs up off its mount and
--! `rolled_high` as it comes down again): the paper wound round the roller
--! (springing up, the frame behind it under it); gone (`gone`): the frame
--! behind where the roller was, lit (as at the picture's edge, no `right`).
--! The colours as the movies show them (8 bits each): the fill takes the
--! picture's nearest. Below them the blackboard is as the picture has it
--! beside the chart's right end, as light as `board` says (from each row on,
--! percent) at the picture's edge, as light as the picture at the chart's end
--! (while the chart rolls, `board` only).
UIProfessorMenu.MOVIE_ROWS = {
  up = {from = ROLLER_BOTTOM + 1, reach = CHART_LEFT,
    board = {43, 88, 62, 91, 70, 100, 126, 95, 134, 93, 142, 99, 150, 123, 158, 111,
      166, 113, 174, 120},
    left = {{96, 84, 72}, {129, 112, 100}, {73, 60, 48}, {40, 24, 16}, {40, 24, 16},
      {40, 24, 16}, {40, 24, 16}, {24, 16, 16}, {12, 12, 16}, {12, 15, 16},
      {12, 16, 16}, {12, 16, 16}, {12, 16, 16}, {12, 16, 16}, {15, 19, 19},
      {16, 20, 20}, {16, 20, 20}, {19, 23, 23}, {20, 24, 24}, {20, 24, 24}, {27, 27, 27}},
    right = {{64, 55, 47}, {161, 149, 108}, {85, 69, 60}, {40, 24, 16}, {24, 16, 16},
      {16, 19, 19}, {16, 20, 20}, {16, 20, 20}, {16, 20, 20}, {16, 20, 20},
      {16, 20, 20}, {16, 20, 20}, {16, 20, 20}, {16, 20, 20}, {16, 20, 20},
      {19, 20, 23}, {20, 23, 24}, {20, 24, 24}, {27, 27, 27}, {28, 28, 28}, {28, 28, 28}}},
  rolled = {from = 0, reach = CHART_LEFT,
    board = {118, 106, 126, 104, 142, 112, 150, 135, 158, 126, 166, 128, 174, 138},
    left = {{85, 101, 121}, {85, 101, 121}, {85, 101, 121}, {81, 93, 113}, {96, 104, 113},
      {225, 202, 177}, {230, 214, 185}, {231, 215, 186}, {231, 215, 186}, {231, 215, 186},
      {231, 215, 186}, {231, 215, 186}, {231, 215, 186}, {219, 195, 170}, {211, 186, 162},
      {195, 174, 154}, {178, 158, 138}, {158, 138, 121}, {121, 105, 93}, {93, 81, 73},
      {89, 77, 69}, {65, 56, 48}, {48, 44, 36}, {40, 24, 16}, {40, 24, 16}, {40, 24, 16},
      {40, 24, 16}, {40, 24, 16}, {51, 31, 16}, {24, 16, 16}, {16, 19, 19}, {16, 20, 20},
      {16, 20, 20}, {16, 20, 20}, {16, 20, 20}, {16, 20, 20}, {19, 23, 23}, {19, 23, 23},
      {20, 24, 24}, {20, 24, 24}, {20, 24, 24}, {20, 24, 24}, {31, 31, 31}},
    right = {{77, 89, 109}, {77, 89, 109}, {77, 89, 109}, {77, 89, 109}, {120, 116, 112},
      {218, 198, 161}, {230, 214, 185}, {231, 215, 186}, {231, 215, 186}, {231, 215, 186},
      {231, 215, 186}, {231, 215, 186}, {231, 215, 186}, {231, 215, 186}, {219, 199, 162},
      {219, 199, 162}, {203, 182, 146}, {190, 170, 134}, {162, 150, 109}, {142, 125, 97},
      {105, 89, 73}, {85, 73, 65}, {73, 65, 56}, {52, 32, 16}, {40, 24, 16}, {40, 24, 16},
      {24, 16, 16}, {20, 23, 23}, {16, 20, 20}, {16, 20, 20}, {16, 20, 20}, {16, 20, 20},
      {16, 20, 20}, {16, 20, 20}, {12, 16, 16}, {16, 20, 20}, {16, 20, 20}, {16, 20, 20},
      {16, 20, 20}, {19, 23, 23}, {20, 24, 24}, {20, 24, 24}, {20, 24, 24}}},
  rolled_high = {from = 0, reach = CHART_LEFT,
    board = {118, 106, 126, 104, 142, 112, 150, 135, 158, 126, 166, 128, 174, 138},
    left = {{85, 101, 121}, {85, 101, 121}, {185, 165, 145}, {218, 194, 169}, {230, 214, 185},
      {231, 215, 186}, {231, 215, 186}, {231, 215, 186}, {231, 215, 186}, {231, 215, 186},
      {231, 215, 186}, {231, 215, 186}, {231, 215, 186}, {219, 195, 170}, {207, 186, 162},
      {195, 174, 154}, {178, 158, 138}, {154, 138, 117}, {117, 105, 93}, {93, 81, 73},
      {73, 65, 56}, {56, 52, 44}, {48, 44, 36}, {40, 24, 16}, {40, 24, 16}, {40, 24, 16},
      {40, 24, 16}, {40, 24, 16}, {51, 31, 16}, {24, 16, 16}, {12, 16, 16}, {12, 16, 16},
      {12, 16, 16}, {12, 16, 16}, {12, 16, 16}, {12, 16, 16}, {19, 23, 23}, {20, 24, 24},
      {20, 24, 24}, {20, 24, 24}, {20, 24, 24}, {20, 24, 24}, {31, 31, 31}},
    right = {{77, 89, 109}, {77, 89, 109}, {161, 141, 124}, {218, 198, 161}, {218, 198, 161},
      {230, 214, 185}, {231, 215, 186}, {231, 215, 186}, {231, 215, 186}, {231, 215, 186},
      {231, 215, 186}, {231, 215, 186}, {231, 215, 186}, {219, 199, 162}, {203, 182, 146},
      {199, 178, 130}, {186, 166, 146}, {170, 154, 117}, {154, 138, 101}, {130, 113, 101},
      {105, 89, 73}, {73, 65, 56}, {56, 52, 44}, {40, 36, 28}, {40, 24, 16}, {40, 24, 16},
      {24, 16, 16}, {12, 16, 16}, {12, 16, 16}, {12, 16, 16}, {12, 16, 16}, {12, 16, 16},
      {12, 16, 16}, {12, 16, 16}, {12, 16, 16}, {12, 16, 16}, {12, 16, 16}, {12, 16, 16},
      {12, 16, 16}, {19, 23, 23}, {20, 24, 24}, {20, 24, 24}, {20, 24, 24}}},
  -- (One frame, 1857 ms: Jan 2026-11-25 saw the roller wound up beside it
  -- while the movie's had sprung up.)
  sprung = {from = 0, reach = CHART_LEFT,
    board = {118, 106, 126, 104, 142, 112, 150, 135, 158, 126, 166, 128, 174, 138},
    left = {{231, 215, 186}, {231, 215, 186}, {231, 215, 186}, {227, 203, 178}, {219, 195, 170},
      {207, 186, 162}, {186, 166, 146}, {170, 150, 134}, {138, 121, 109}, {117, 105, 93},
      {85, 73, 65}, {65, 56, 48}, {56, 52, 44}, {73, 48, 32}, {113, 69, 40}, {130, 81, 48},
      {138, 89, 56}, {138, 89, 56}, {105, 73, 48}, {121, 85, 56}, {121, 85, 56}, {121, 85, 56},
      {73, 48, 32}, {52, 32, 16}, {40, 24, 16}, {40, 24, 16}, {40, 24, 16}, {52, 32, 16},
      {52, 32, 16}, {32, 28, 24}, {20, 24, 24}, {20, 24, 24}, {20, 24, 24}, {32, 32, 32},
      {32, 32, 32}, {32, 32, 32}, {32, 32, 32}, {32, 32, 32}, {32, 32, 32}, {32, 32, 32},
      {32, 32, 32}, {32, 32, 32}, {32, 32, 32}},
    right = {{219, 199, 162}, {231, 215, 186}, {231, 215, 186}, {231, 215, 186}, {231, 215, 186},
      {231, 215, 186}, {231, 215, 186}, {231, 215, 186}, {227, 203, 178}, {219, 199, 162},
      {203, 182, 146}, {207, 186, 162}, {190, 170, 134}, {170, 150, 134}, {154, 134, 117},
      {117, 97, 85}, {93, 81, 73}, {73, 65, 56}, {85, 60, 44}, {162, 109, 77}, {154, 105, 77},
      {146, 101, 73}, {105, 77, 56}, {65, 40, 24}, {40, 24, 16}, {40, 24, 16}, {24, 16, 16},
      {12, 16, 16}, {12, 16, 16}, {12, 16, 16}, {12, 16, 16}, {12, 16, 16}, {12, 16, 16},
      {12, 16, 16}, {20, 24, 24}, {20, 24, 24}, {20, 24, 24}, {20, 24, 24}, {20, 24, 24},
      {20, 24, 24}, {20, 24, 24}, {20, 24, 24}, {20, 24, 24}}},
  -- (The whole fill wide, the mount too, as the frame is over the movie's
  -- first 100 columns, averaged over its frames once the roller is gone: by
  -- the right end's mount the frame is darker, with a thinner bottom edge,
  -- and from the mount on the fill was that; at the picture's very edge its
  -- light runs a row lower, a streak, Jan 2026-11-25.)
  gone = {from = 0, reach = -SIDE_W,
    board = {34, 115, 38, 109, 46, 100, 118, 106, 126, 104, 142, 112, 150, 135, 158, 126,
      166, 128, 174, 137},
    left = {{86, 101, 122}, {84, 97, 118}, {82, 95, 115}, {79, 92, 112}, {78, 90, 110},
      {78, 90, 110}, {73, 78, 93}, {69, 46, 31}, {186, 177, 171}, {188, 180, 174},
      {161, 149, 139}, {139, 122, 110}, {130, 102, 83}, {130, 93, 68}, {137, 93, 65},
      {141, 95, 66}, {146, 98, 69}, {149, 101, 72}, {151, 103, 75}, {148, 102, 76},
      {143, 101, 75}, {132, 97, 73}, {91, 66, 49}, {51, 31, 16}, {38, 24, 14}, {38, 24, 14},
      {39, 24, 15}, {41, 25, 15}, {43, 27, 15}, {32, 27, 23}, {20, 24, 24}, {26, 28, 28},
      {32, 32, 32}, {32, 32, 32}}},
  board = {from = 0, reach = CHART_LEFT, left = {}, right = {},
    board = {142, 112, 150, 135, 158, 126, 166, 128, 174, 132}},
}

--! When his movies show what UIProfessorMenu.MOVIE_ROWS has: the time of the
--! frame (milliseconds) and the look from then on (false: none).
UIProfessorMenu.MOVIE_LOOK = {
  coming = {0, "up", 7714, "board", 8143, false},
  leaving = {1643, "board", 1786, "rolled", 1857, "sprung", 1929, "rolled_high", 2000, "gone"},
}

--! What one of his movies (`leaving` or coming) shows at `pts`
--! (milliseconds) of UIProfessorMenu.MOVIE_ROWS: its name, or nil.
function UIProfessorMenu.lookInMovie(leaving, pts)
  local keys = UIProfessorMenu.MOVIE_LOOK[leaving and "leaving" or "coming"]
  local look = false
  for i = 1, #keys - 1, 2 do
    if pts >= keys[i] then look = keys[i + 1] end
  end
  return look or nil
end

--! The chart's bottom edge in one of his movies (`leaving` or coming) at
--! `pts` (milliseconds; the movie's clock, which shows the frame of that
--! time when the screen is drawn often): its row, or false when it is gone.
function UIProfessorMenu.chartInMovie(leaving, pts)
  local keys = UIProfessorMenu.MOVIE_CHART[leaving and "leaving" or "coming"]
  local bottom = keys[2]
  for i = 3, #keys - 1, 2 do
    if pts >= keys[i] then bottom = keys[i + 1] end
  end
  return bottom
end

--! Which row of the chart as the picture has it is at row `y` (from under
--! the roller to `bottom`) when its bottom edge is at row `bottom` in his
--! movies: rolling, the whole chart is higher under the roller's shadow;
--! springing back, its paper is squeezed from STRETCH_FROM down; tugged, it is
--! drawn out at PULL_FROM. `exact`: springing back, the row as a fraction
--! (to draw it a fraction of a row higher or lower), not the nearest row.
function UIProfessorMenu.chartRow(y, bottom, exact)
  if bottom > CHART_BOTTOM then
    if y <= PULL_FROM then return y end
    return math.max(PULL_FROM, y - (bottom - CHART_BOTTOM))
  elseif bottom < DOWN_FROM then
    if y <= ROLLER_SHADOW then return y end
    return y + CHART_BOTTOM - bottom
  elseif y <= STRETCH_FROM then
    return y
  end
  local row = STRETCH_FROM + (y - STRETCH_FROM) * (CHART_BOTTOM - STRETCH_FROM)
      / (bottom - STRETCH_FROM)
  return exact and row or math.floor(row + 0.5)
end

--! How light the chart is in his coming movie while he turns and points,
--! against the picture (the movie's light changes as he moves): the time of
--! the frame (milliseconds) and, from then on, the percent at the chart's
--! upper part (LIGHT_TOP_ROW) and at its lower part (LIGHT_LOW_ROW), measured
--! on the movie's frames beside the picture's edge. Elsewhere it is as light.
--! (Measured again on 2026-11-24 frame by frame, against the picture's paper
--! at its left edge in 5-row bands; and leaving too.)
UIProfessorMenu.MOVIE_LIGHT = {
  coming = {8143, 101, 104, 8214, 100, 105, 8286, 100, 107, 8357, 101, 107, 8429, 101, 108,
    8500, 101, 107, 8786, 101, 106, 8857, 101, 105, 9000, 101, 104, 9143, 100, 103,
    9286, 100, 101, 9357, 100, 100, 9500, 100, 98, 9571, 100, 97, 9714, 99, 96,
    9786, 99, 95, 9857, 99, 94, 9929, 99, 93, 10500, 100, 93, 10571, 100, 94,
    10643, 100, 95, 10714, 101, 95, 10857, 102, 97, 10929, 102, 98, 11000, 103, 99,
    11071, 104, 101, 11214, 104, 102, 11286, 105, 103, 11429, 106, 104, 11500, 106, 105,
    11714, 107, 106, 11786, 106, 106, 11857, 106, 105, 11929, 105, 104, 12000, 105, 105,
    12071, 104, 103, 12143, 103, 102, 12214, 102, 101, 12286, 101, 101, 12357, 101, 100,
    12429, 100, 100},
  leaving = {0, 101, 102, 1429, 102, 102, 1500, 103, 102, 1571, 101, 102, 1643, 100, 100},
}
-- (Bands of LIGHT_BAND rows, LIGHT_STEP percent apart: 8 rows and 2 percent
-- showed as squares on the paper, Jan 2026-11-24.)
local LIGHT_TOP_ROW, LIGHT_LOW_ROW, LIGHT_BAND, LIGHT_STEP = 57, 120, 4, 1

-- How light (percent) the chart's band of rows from `row` is, when it is `top`
-- at its upper part and `low` at its lower part (lightInMovie's).
local function bandLight(row, top, low)
  local t = (row + LIGHT_BAND / 2 - LIGHT_TOP_ROW) / (LIGHT_LOW_ROW - LIGHT_TOP_ROW)
  t = math.max(0, math.min(1, t))
  return LIGHT_STEP * math.floor((top + (low - top) * t) / LIGHT_STEP + 0.5)
end

-- While the chart rolls (pulled down, rolling up), the roller's shadow on its
-- paper fades out lower in his movies than the picture's (to ROLLER_SHADOW):
-- from each row on, how light the paper is there, percent (measured on
-- 2026-11-25 against the fill, frames 109 to 113 coming and 23 and 24
-- leaving; Jan saw a lighter block under the shadow).
local ROLLING_LIGHT = {ROLLER_SHADOW + 1, 86, ROLLER_SHADOW + 2, 90, 44, 95, 50, 100}

-- The bands of rows {from, to, percent} as light as ROLLING_LIGHT has them
-- (not 100) above the chart's bottom edge at row `bottom`.
local function rollingBands(bottom)
  local bands = {}
  for i = 1, #ROLLING_LIGHT - 1, 2 do
    local from, light = ROLLING_LIGHT[i], ROLLING_LIGHT[i + 1]
    local to = math.min((ROLLING_LIGHT[i + 2] or PIC_H) - 1, bottom)
    if light ~= 100 and from <= to then bands[#bands + 1] = {from, to, light} end
  end
  return bands
end

--! How light the blackboard under and beside the chart is in his movies while
--! the chart is down (it changes with his light as he turns and points, from
--! 72 to 124 percent): the time of the frame (milliseconds) and the percent
--! against the picture's board under the chart, from then on, measured on
--! the movies' frames at the picture's left part.
UIProfessorMenu.MOVIE_BOARD = {
  coming = {8143, 104, 8214, 100, 8286, 90, 8357, 80, 8500, 72, 8571, 76, 8643, 82,
    8714, 92, 8786, 96, 8857, 102, 9000, 104, 9214, 106, 9286, 108, 9357, 104,
    9571, 108, 9643, 112, 9714, 116, 9786, 120, 9929, 122, 10000, 124, 10571, 122,
    10643, 120, 10714, 118, 10786, 116, 10857, 108, 10929, 104, 11000, 100, 11071, 92,
    11143, 88, 11286, 84, 11429, 80, 11500, 76, 11643, 72, 12000, 76, 12071, 80,
    12143, 84, 12214, 86, 12286, 94, 12357, 100},
  leaving = {0, 124, 214, 120, 357, 122, 1143, 120, 1214, 116, 1429, 108, 1500, 94,
    1571, 122, 1643, 100},
}

--! How light the blackboard is in one of his movies at `pts` (milliseconds)
--! while the chart is down: percent (100: as in the picture).
function UIProfessorMenu.boardInMovie(leaving, pts)
  local keys = UIProfessorMenu.MOVIE_BOARD[leaving and "leaving" or "coming"]
  local percent = 100
  for i = 1, #keys - 1, 2 do
    if pts >= keys[i] then percent = keys[i + 1] end
  end
  return percent
end

--! How light the chart is in one of his movies at `pts` (milliseconds): the
--! percent at its upper and its lower part, or nil when as in the picture.
function UIProfessorMenu.lightInMovie(leaving, pts)
  local keys = UIProfessorMenu.MOVIE_LIGHT[leaving and "leaving" or "coming"]
  if not keys or pts < keys[1] then return nil end
  local top, low = 100, 100
  for i = 1, #keys - 2, 3 do
    if pts >= keys[i] then top, low = keys[i + 1], keys[i + 2] end
  end
  if top == 100 and low == 100 then return nil end
  return top, low
end
-- Where each picture of his arm (Main02M 1 to 5) goes on the picture. They
-- do not share a corner: each is a pixel or two off the others (found by
-- matching each one's lines with the picture's).
local ARMS_AT = {{18, 23}, {18, 23}, {18, 22}, {16, 23}, {18, 23}}
-- The chart's own writing (x0, y0, x1, y1), rubbed out when he says what he
-- points at: under the small skull, between the big skull and the paper's
-- shaded edge. The end of his speech mark, over that edge (MARK), is mended
-- with a row under it (MARK_FROM).
local WRITING = {123, 67, 167, 110}
local MARK = {168, 79, 177, 85}
local MARK_FROM = 89
-- Where he writes: the name of what he points at, and under it what it
-- does, clear of the small skull and away from the big skull and the
-- chart's edge (closer to them only for a word too long for that, as
-- openth.org/discord); in the middle of where the chart's writing was, or
-- further down its blank paper when there is more to say.
local TEXT_X, TEXT_W = 126, 40
local WIDE_X, WIDE_W = 123, 47
local TEXT_TOP, TEXT_BOTTOM, WRITING_BOTTOM = 67, 152, 111
local NAME_H, GAP = 26, 4
-- The tips are asked for in chalk on the blackboard under the chart, at its
-- left, away from the professor's arm.
local CHALK_X, CHALK_TOP, CHALK_BOTTOM = 6, 161, 181
local CHALK = {red = 226, green = 226, blue = 214}
local CHALK_LIT = {red = 255, green = 232, blue = 120}
-- The sound of pointing at something, as on the game's other menus.
local HOVER_SOUND = "HLight5.wav"
-- The version lines, as on the list menu.
local LABEL_TTF_COL = {red = 255, green = 255, blue = 255, alpha = 192}

--! The spots, in the order they are looked for: the menu item (its name in
--! _S.main_menu and its tooltip in _S.tooltip.main_menu), the UIMainMenu
--! method it calls, its outline on the picture (x, y pairs) and, on the
--! skull, the picture of his arm pointing at it; elsewhere, what turns pink
--! if not the shape of the drawing in its outline (`pink`: outlines, all of
--! whose paper turns pink with `fill`, each leg on its own).
UIProfessorMenu.SPOTS = {
  {item = "continue", button = "buttonContinueGame", arm = 1,
    outline = {57, 31, 75, 26, 105, 31, 96, 47, 85, 56, 71, 50}},
  {item = "new_game", button = "buttonNewGame", arm = 2,
    outline = {50, 37, 56, 33, 82, 59, 72, 71, 52, 83, 44, 54}},
  {item = "load_game", button = "buttonLoadGame", arm = 3,
    outline = {106, 33, 112, 35, 119, 45, 119, 63, 112, 84, 92, 71, 84, 60}},
  {item = "exit", button = "buttonExit", arm = 5,
    outline = {64, 122, 98, 122, 99, 143, 89, 148, 77, 148, 66, 141}},
  {item = "multiplayer", button = "buttonMultiplayer", arm = 4,
    outline = {55, 85, 85, 60, 114, 85, 120, 98, 104, 115, 89, 118, 67, 116, 49, 97}},
  {item = "custom_campaign", button = "buttonCustomCampaign",
    outline = {4, 33, 26, 33, 28, 45, 24, 57, 20, 65, 9, 65, 5, 57, 2, 45}},
  {item = "custom_level", button = "buttonCustomGame",
    outline = {0, 66, 33, 66, 34, 96, 0, 96},
    pink = {{0, 68, 30, 68, 30, 96, 0, 96}}},
  {item = "discord", button = "buttonDiscord",
    outline = {30, 96, 42, 96, 43, 111, 30, 111},
    pink = {{fill = true, 31, 96, 39, 96, 41, 100, 42, 108, 38, 111, 29, 111, 28, 104, 31, 100}}},
  {item = "map_edit", button = "buttonMapEdit",
    outline = {2, 97, 30, 97, 30, 112, 33, 148, 1, 148, 1, 112},
    pink = {{fill = true, 2, 96, 13, 96, 13, 112, 14, 128, 14, 140, 16, 147, 0, 147, 1, 140, 4, 128, 3, 112},
      {fill = true, 20, 96, 29, 96, 29, 112, 31, 122, 31, 138, 34, 142, 34, 147, 19, 147, 20, 140, 20, 112}}},
  {item = "options", button = "buttonOptions",
    outline = {133, 26, 160, 24, 168, 35, 168, 50, 158, 58, 147, 66, 136, 62, 132, 45}},
}

--! Rectangles of the picture (x, y, width, height) for the tests: where he
--! writes and what he rubs out, and where the chalk goes.
UIProfessorMenu.TEXT = {WIDE_X, TEXT_TOP, WIDE_W, TEXT_BOTTOM - TEXT_TOP}
UIProfessorMenu.WRITING = {WRITING[1], WRITING[2], WRITING[3] - WRITING[1] + 1,
    WRITING[4] - WRITING[2] + 1}
UIProfessorMenu.CHALK = {CHALK_X, CHALK_TOP, 90, CHALK_BOTTOM - CHALK_TOP}
--! How wide the fill at the picture's left is, in picture pixels.
UIProfessorMenu.SIDE_W = SIDE_W

--! Whether the point is inside an outline (x, y pairs).
local function inside(outline, x, y)
  local hit = false
  local n = #outline
  local jx, jy = outline[n - 1], outline[n]
  for i = 1, n - 1, 2 do
    local ix, iy = outline[i], outline[i + 1]
    if (iy > y) ~= (jy > y) and x < (jx - ix) * (y - iy) / (jy - iy) + ix then
      hit = not hit
    end
    jx, jy = ix, iy
  end
  return hit
end

--! The spot at a point of the picture, or nil.
function UIProfessorMenu.spotAtPicture(x, y)
  for _, spot in ipairs(UIProfessorMenu.SPOTS) do
    if inside(spot.outline, x, y) then return spot end
  end
end

--! Where the picture goes on a screen `w` by `h` pixels: as big as fills the
--! screen, cutting off at most the professor's back (the chart stays at the
--! left) and the edges of the wall, with black bars above and below where the
--! screen's shape needs more. On a wider screen the picture keeps to the
--! right and the fill (SIDE_W) is at its left. The corner is a whole number
--! of picture pixels from the screen's.
--!return (table) `scale` (screen pixels to each picture pixel), the corner
--! in picture pixels (`px`, `py`) and in screen pixels (`x`, `y`)
function UIProfessorMenu.layout(w, h)
  local f = math.min(math.max(w / PIC_W, h / PIC_H), w / KEEP_W,
      h / (KEEP_BOTTOM - KEEP_TOP))
  local x = PIC_W * f <= w and w - PIC_W * f or 0
  local y = (h - PIC_H * f) / 2
  if PIC_H * f > h then
    y = math.max(math.min(y, h - KEEP_BOTTOM * f), -KEEP_TOP * f)
  end
  -- (Up, not to the nearest, so that no black is left at the right.)
  local px, py = math.ceil(x / f - 1e-6), math.floor(y / f + 0.5)
  if py < -KEEP_TOP then py = -KEEP_TOP end
  return {scale = f, px = px, py = py, x = px * f, y = py * f}
end

--! Reflects `s` back and forth between `lo` and `hi`.
local function reflect(s, lo, hi)
  local period = 2 * (hi - lo)
  local t = (s - lo) % period
  return lo + (t <= hi - lo and t or period - t)
end

--! Which column of the picture the fill at the picture's left (x from
--! -SIDE_W to -1) takes its row `y`'s pixel from: inside the chart, beside
--! the skeleton its other half (it is cut at the picture's edge) and then
--! plain paper, above and below it (the roller, the paper's top and bottom,
--! the blackboard under the chart) the mirror image of the picture's edge; at
--! the chart's left end, the mirror image of its right end, the roller's
--! mount with it; then the blackboard and its frame as they are beside the
--! chart, there and back again. With the chart rolled up (`kind` "up") the
--! blackboard is behind it; with it and its roller gone ("gone"), also the
--! frame behind the roller (its mount stays). The chart down: "down" or nil.
function UIProfessorMenu.sideColumn(x, y, kind)
  local mirror = CHART_LEFT + CHART_RIGHT - x
  if y >= LEDGE_TOP then
    return reflect(x < CHART_LEFT and mirror or -x - 1, 0, BOARD_TO)
  elseif kind == "gone" and y <= FRAME_BOTTOM and mirror < MOUNT_FROM then
    return reflect(mirror, FRAME_FROM, PIC_W - 1)
  elseif kind and kind ~= "down" and y > ROLLER_BOTTOM and x >= CHART_LEFT then
    return reflect(mirror, BOARD_FROM, BOARD_TO)
  elseif x >= CHART_LEFT + EDGE_W then
    if y >= SKELETON_TOP and y <= SKELETON_BOTTOM then
      if y >= SKELETON_FEET then return PAPER_COLUMN end
      return math.min(SKELETON_2X - x, PAPER_COLUMN)
    end
    return -x - 1
  elseif mirror <= MOUNT_TO then
    return mirror
  elseif y <= FRAME_BOTTOM then
    return reflect(mirror, FRAME_FROM, PIC_W - 1)
  end
  return reflect(mirror, BOARD_FROM, BOARD_TO)
end

--! 0 for `x` from `from` on, 1 left of `to`, and in between more each column.
local function ramp(x, from, to)
  if x >= from then return 0 end
  if x < to then return 1 end
  return (from - x) / (from - to + 1)
end

--! How much of the chart's right end (its mirror image) the fill's column
--! `x` at the chart's left end has in row `y`: 0 up to BLEND_FROM (only what
--! goes on from the picture's edge), then more each column until its edge
--! (1); in the bottom line's rows from the picture's edge to LINE_TO.
function UIProfessorMenu.endBlend(x, y)
  if y and y >= LINE_TOP and y <= LINE_LOW then return ramp(x, -1, LINE_TO) end
  return ramp(x, BLEND_FROM, CHART_LEFT + EDGE_W)
end

-- Beside the picture's edge (LIVE_W columns, up to the chart's left end) the
-- fill is taken from the frame his movie shows, as it is taken from the
-- picture: its colours and light are the movie's, frame by frame (Jan
-- 2026-11-25: one piece, not glued on; the chart's bottom line and edge
-- beside the picture were not the movie's). Rolled up and rolling too (Jan,
-- later that day: the red line a row off as he pulled it down; his hand
-- reaches only the columns the skeleton's other half is taken from, while
-- those rows are below the chart, taken from the picture's edge). Once the
-- chart is gone only the frame above the board (GONE_ROWS rows: the roller
-- falls through those below; Jan: a made-up part beside the frame). Not the
-- chart's left end (the mirror image of its right end, where he stands).
local LIVE_W = -(CHART_LEFT + EDGE_W)
local GONE_ROWS = 53

--! What of the frame his movie shows to draw beside the picture's edge while
--! the chart's bottom edge is at row `bottom` (UIProfessorMenu.chartInMovie):
--! a list of {sx, sy, sw, sh (the frame's pixels), x, y, w, h (the fill's: x
--! from -LIVE_W, rows as the picture's), flip (mirrored), alpha (0 to 255)},
--! the columns as UIProfessorMenu.sideColumn takes them from the picture,
--! the rows the frame's own (the chart moves in it). The last columns fade
--! into the fill drawn from the picture as endBlend has it. With the chart
--! gone (`bottom` false or nil) only its first GONE_ROWS rows.
function UIProfessorMenu.movieStrip(bottom)
  local draws = {}
  -- Rows and where their columns come from: the picture's edge mirrored, the
  -- skeleton's other half, or the paper beside his feet.
  local bands = {{0, GONE_ROWS, "edge"}}
  if bottom then
    -- The chart's row as the picture has it at the frame's row `y`: rolling,
    -- what is drawn on it moves on under the roller's shadow too (only the
    -- shadow stays; its skeleton's legs were mirrored there).
    local function chartAt(y)
      if bottom >= DOWN_FROM then return UIProfessorMenu.chartRow(y, bottom, true) end
      return y <= ROLLER_BOTTOM and y or y + CHART_BOTTOM - bottom
    end
    -- The frame's row with the chart's row `r` as the picture has it.
    local function rowOf(r)
      local lo, hi = 0, PIC_H
      for _ = 1, 24 do
        local mid = (lo + hi) / 2
        if chartAt(mid) < r then lo = mid else hi = mid end
      end
      return math.floor(hi + 0.5)
    end
    local top, feet, below = rowOf(SKELETON_TOP), rowOf(SKELETON_FEET), rowOf(SKELETON_BOTTOM + 1)
    bands = {{0, top, "edge"}, {top, feet, "skeleton"}, {feet, below, "paper"},
      {below, PIC_H, "edge"}}
  end
  -- Columns with as much of the frame (fully from BLEND_FROM on).
  local groups = {{BLEND_FROM, -1}}
  for x = BLEND_FROM - 1, -LIVE_W, -1 do groups[#groups + 1] = {x, x} end
  local function add(sx, sw, x0, x1, band, flip, alpha)
    draws[#draws + 1] = {sx = sx, sy = band[1], sw = sw, sh = band[2] - band[1],
      x = x0, y = band[1], w = x1 - x0 + 1, h = band[2] - band[1], flip = flip, alpha = alpha}
  end
  for _, group in ipairs(groups) do
    local x0, x1 = group[1], group[2]
    local alpha = math.floor(255 * (1 - UIProfessorMenu.endBlend(x0)) + 0.5)
    for _, band in ipairs(bands) do
      if band[2] > band[1] then
        if band[3] == "edge" then
          add(-x1 - 1, x1 - x0 + 1, x0, x1, band, true, alpha)
        elseif band[3] == "paper" then
          add(PAPER_COLUMN, 1, x0, x1, band, false, alpha)
        else
          -- The skeleton's other half to PAPER_COLUMN, its paper beyond.
          local split = SKELETON_2X - PAPER_COLUMN
          if x1 >= split then
            local a = math.max(x0, split)
            add(SKELETON_2X - x1, x1 - a + 1, a, x1, band, true, alpha)
          end
          if x0 < split then add(PAPER_COLUMN, 1, x0, math.min(x1, split - 1), band, false, alpha) end
        end
      end
    end
  end
  return draws
end

--! Draws UIProfessorMenu.movieStrip(`bottom`) on `canvas` beside his movie
--! with `drawPart` (the movie player's: source and screen rectangles, flip,
--! alpha; false when it has no frame to draw from).
function UIProfessorMenu.drawMovieStrip(canvas, bottom, drawPart)
  local l = UIProfessorMenu.layout(canvas:getRenderSize())
  if l.px <= 0 then return end
  -- Straight onto the screen. In fullscreen the engine draws everything
  -- after a scale, back to 1 too, into a picture of its own that it lays over
  -- the screen as it is, see-through where nothing was drawn: a part drawn
  -- there half see-through was laid on half see-through again, darker (Jan's
  -- work Mac, 2026-11-26). A "bitmap" scale lays that picture down and makes
  -- no new one.
  canvas:scale(1, "bitmap")
  local s = l.scale
  for _, d in ipairs(UIProfessorMenu.movieStrip(bottom)) do
    if not drawPart(d.sx, d.sy, d.sw, d.sh, (l.px + d.x) * s, (l.py + d.y) * s, d.w * s,
        d.h * s, d.flip, d.alpha) then
      return
    end
  end
end

--! Decodes a sprite of "complex" chunks as the engine does (chunk_renderer):
--! its colours by position from 0 (left to right, top to bottom), without
--! the transparent ones.
--!param data (string) the sheet's data (a .dat file)
--!param from (integer) the sprite's first byte in it (from 1)
--!param to (integer) its last byte
function UIProfessorMenu.decodeChunks(data, from, to, width, height)
  local pixels = {}
  local total, pos, x, skip_eol = width * height, 0, 0, false
  local function put(count, colour)
    for k = 0, count - 1 do
      if pos + k < total and colour ~= 255 then pixels[pos + k] = colour end
    end
  end
  local function step(count)
    pos = pos + count
    x = (x + count) % width
    skip_eol = true
  end
  local i = from
  while i <= to and pos < total do
    local b = data:byte(i)
    i = i + 1
    if b == 0 then
      -- The end of a line, unless the line was just filled.
      if x ~= 0 or not skip_eol then step(width - x) end
      skip_eol = false
    elseif b < 0x40 then
      -- (No further than the sprite's data.)
      local count = math.min(b, to - i + 1)
      for k = 0, count - 1 do
        local colour = data:byte(i + k)
        if pos + k < total and colour ~= 255 then pixels[pos + k] = colour end
      end
      i = i + count
      step(count)
    elseif b >= 0x80 and b < 0xC0 then
      step(b - 0x80)
    else
      local count, colour
      if b == 0xFF then
        count, colour = data:byte(i, i + 1)
        i = i + 2
      else
        count = b < 0x80 and b - 60 or b - 124
        colour = data:byte(i)
        i = i + 1
      end
      put(count or 0, colour or 255)
      step(count or 0)
    end
  end
  return pixels
end

--! The runs of paper of a part of the drawing ({x, y, width} on the
--! picture), what turns pink: in each row of the outline, the paper between
--! the first and the last of the drawing's lines there (the shape of a bone,
--! not the paper around it), or all of it with `outline.fill`; the lines are
--! left as they are.
--!param pixels (string) the picture (Main01M.dat)
--!param colours (string) its palette (Main01M.pal, 6 bits a colour)
local function paperRuns(outline, pixels, colours, runs)
  local x0, y0, x1, y1 = PIC_W, PIC_H, 0, 0
  for i = 1, #outline - 1, 2 do
    x0, x1 = math.min(x0, outline[i]), math.max(x1, outline[i])
    y0, y1 = math.min(y0, outline[i + 1]), math.max(y1, outline[i + 1])
  end
  x0, y0 = math.max(0, x0), math.max(0, y0)
  x1, y1 = math.min(PIC_W - 1, x1), math.min(PIC_H - 1, y1)
  local function lightness(x, y)
    local c = pixels:byte(y * PIC_W + x + 1)
    local r, g, b = colours:byte(c * 3 + 1, c * 3 + 3)
    return r + g + b
  end
  for y = y0, y1 do
    -- (The paper is about 50, 45, 39, the lines under 30 each.)
    local first, last
    for x = x0, x1 do
      if inside(outline, x + 0.5, y + 0.5) and (outline.fill or lightness(x, y) < 120) then
        first = first or x
        last = x
      end
    end
    local from
    for x = first or 1, last and last + 1 or 0 do
      local paper = x <= last and inside(outline, x + 0.5, y + 0.5) and lightness(x, y) > 112
      if paper and not from then
        from = x
      elseif not paper and from then
        runs[#runs + 1] = {from, y, x - from}
        from = nil
      end
    end
  end
  return runs
end

--! The picture's colours as the game shows them ({r, g, b}, 8 bits each).
local function colourTable(colours)
  local rgb = {}
  local function up(v) return math.floor(v * 255 / 63 + 0.5) end
  for c = 0, 255 do
    local r, g, b = colours:byte(c * 3 + 1, c * 3 + 3)
    rgb[c] = {up(r), up(g), up(b)}
  end
  return rgb
end

local function distance2(p, q)
  return (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 + (p[3] - q[3]) ^ 2
end

--! For each colour of the picture, its pink: what the paper of a skeleton's
--! part he points at turns to. In his pictures of the skull the pinks are
--! about the paper's colours times 0.87, 0.69, 0.87; the nearest of the
--! palette's pinks to that.
local function pinkMap(rgb)
  local pinks = {}
  for c = 0, 254 do
    local r, g, b = rgb[c][1], rgb[c][2], rgb[c][3]
    if r - g >= 30 and b - g >= 8 and b <= r then pinks[#pinks + 1] = c end
  end
  local map = {}
  for c = 0, 255 do
    local want = {rgb[c][1] * 0.87, rgb[c][2] * 0.69, rgb[c][3] * 0.87}
    local best, best_d = c, math.huge
    for _, p in ipairs(pinks) do
      local d = distance2(rgb[p], want)
      if d < best_d then best, best_d = p, d end
    end
    map[c] = best
  end
  return map
end

--! The chart's writing rubbed out: the colour of each pixel that changes, by
--! position (from 1). The paper of a row is the commonest light colour in
--! the rows around it (it is lighter at the top), and every pixel not close
--! to it becomes it.
local function rubOut(base, rgb)
  local x0, y0, x1, y1 = WRITING[1], WRITING[2], WRITING[3], WRITING[4]
  local changes, paper = {}, nil
  for y = y0, y1 do
    local counts, most = {}, 0
    for yy = y - 3, y + 3 do
      for x = x0, x1 do
        local c = base[yy * PIC_W + x + 1]
        local p = rgb[c]
        if p[1] + p[2] + p[3] >= 515 then
          local n = (counts[c] or 0) + 1
          counts[c] = n
          if n > most then most, paper = n, c end
        end
      end
    end
    if paper then
      for x = x0, x1 do
        local i = y * PIC_W + x + 1
        if distance2(rgb[base[i]], rgb[paper]) > 100 then changes[i] = paper end
      end
    end
  end
  for y = MARK[2], MARK[4] do
    for x = MARK[1], MARK[3] do
      changes[y * PIC_W + x + 1] = base[MARK_FROM * PIC_W + x + 1]
    end
  end
  return changes
end

local art -- false once known that the game files do not have it

--! The professor's pictures from the game files (the demo has them too), or
--! nil without them.
--!return (table) `picture` (the bitmap), `base` (its colours by position,
--! from 1), `arms` (his arm's pictures: `pixels` as decodeChunks gives them,
--! `w`), `pink` (each skeleton spot's paper runs, by item), `pink_of` (the
--! pink of each colour), `rgb` (the palette's colours), `rubbed` (rubOut's
--! changes), `views` (the pictures made for the items pointed at, by item)
--! and `sides` (the fills at the picture's left, once made, by kind)
function UIProfessorMenu.art(app)
  if art == nil then
    local ok, result = pcall(function()
      local gfx = app.gfx
      local pixels = app:readDataFile("QData", "Main01M.dat")
      local colours = app:readDataFile("QData", "Main01M.pal")
      assert(#pixels >= PIC_W * PIC_H and #colours >= 768, "short picture or palette")
      local loaded = {
        picture = gfx:loadRaw("Main01M", PIC_W, PIC_H, "QData"),
        base = {},
        arms = {},
        pink = {},
        views = {},
        sides = {},
        side_data = {},
        palettes = {},
      }
      for i = 1, PIC_W * PIC_H do loaded.base[i] = pixels:byte(i) end
      local rgb = colourTable(colours)
      loaded.rgb = rgb
      loaded.pal_data = colours
      loaded.pink_of = pinkMap(rgb)
      loaded.rubbed = rubOut(loaded.base, rgb)
      -- His arm: the sheet's table has the start (4 bytes), width and height
      -- of each picture; a picture's data ends where the next one's starts.
      local tab = app:readDataFile("QData", "Main02M.tab")
      local dat = app:readDataFile("QData", "Main02M.dat")
      local function start(e)
        local a, b, c, d = tab:byte(e, e + 3)
        return a + 256 * (b + 256 * (c + 256 * d)) + 1
      end
      for n = 1, #ARMS_AT do
        local e = n * 6 + 1
        assert(#tab >= e + 5, "short arm table")
        local from, to = start(e), #dat
        for other = 1, #tab - 5, 6 do
          local s = start(other)
          if s > from and s - 1 < to then to = s - 1 end
        end
        local w, h = tab:byte(e + 4, e + 5)
        loaded.arms[n] = {pixels = UIProfessorMenu.decodeChunks(dat, from, to, w, h), w = w}
      end
      for _, spot in ipairs(UIProfessorMenu.SPOTS) do
        if not spot.arm then
          local runs = {}
          for _, outline in ipairs(spot.pink or {spot.outline}) do
            paperRuns(outline, pixels, colours, runs)
          end
          loaded.pink[spot.item] = runs
        end
      end
      return loaded
    end)
    if not ok then print("No professor menu (the list instead): " .. tostring(result)) end
    art = ok and result or false
  end
  return art or nil
end

--! Whether the main menu is the professor's: the setting is on and the game
--! files have his pictures.
function UIProfessorMenu.wanted(app)
  return app.config.professor_menu ~= false and UIProfessorMenu.art(app) ~= nil
end

local CHARS = {}
for c = 0, 255 do CHARS[c] = string.char(c) end

--! A bitmap of the picture's palette from its colours (a string, a byte for
--! each pixel, `width` pixels a row), or of `palette`.
local function bitmapOf(app, data, width, palette)
  local gfx = app.gfx
  palette = palette or gfx:getPalette("Main01M.pal")
  local bitmap = TH.bitmap()
  -- (Made again when the renderer is, as the game's pictures are.)
  local function load(bm)
    bm:setPalette(palette)
    assert(bm:load(data, width, gfx.target))
  end
  load(bitmap)
  gfx.reload_functions[bitmap] = load
  return bitmap
end

--! The keys the fill made with these (side's arguments) is kept under: its
--! own, and its pixels' (the same for each `light`).
function UIProfessorMenu.fillKey(kind, light, look, movie)
  local data_key = (look and kind .. "/" .. look or kind) .. (movie and kind == "down" and "/movie" or "")
  return light and data_key .. light or data_key, data_key
end

-- While UIProfessorMenu.prepare makes fills beforehand: when (SDL's ticks) it
-- stops for now, at the next row.
local pause_at = nil
local function pause()
  if pause_at and require("sdl").getTicks() >= pause_at then coroutine.yield() end
end

--! The fill at the picture's left (SIDE_W wide), made the first time it is
--! needed, from the picture with the chart's writing rubbed out (the end of
--! his speech mark is over the chart's right end). Beside the skeleton only
--! its lines are taken (what is darker than the paper); its paper there is
--! the mirror image of the paper at the picture's edge, which goes on from
--! it, with the paper's commonest colour (in the rows around) where that
--! has the skeleton's lines. `kind` as UIProfessorMenu.sideColumn's ("down",
--! "up" or "gone"); `light`, a percent, makes it that light; `look`, what his
--! movie shows there (UIProfessorMenu.MOVIE_ROWS); `movie`, beside his movies
--! (the chart's bottom line as they have it). Made once each.
local function side(app, loaded, kind, light, look, movie)
  local key, data_key = UIProfessorMenu.fillKey(kind, light, look, movie)
  if loaded.sides[key] then return loaded.sides[key] end
  if not loaded.side_data[data_key] then
    local base, rubbed, rgb = loaded.base, loaded.rubbed, loaded.rgb
    local function at(x, y)
      local i = y * PIC_W + x + 1
      return rubbed[i] or base[i]
    end
    local function bright(c)
      local p = rgb[c]
      return p[1] + p[2] + p[3]
    end
    -- The colour of the picture's palette nearest to `w` of `q` mixed into
    -- `p` ({r, g, b} each; the transparent colour left out).
    local nearest = {}
    local function nearestOf(p, q, w)
      local r = math.floor(p[1] + (q[1] - p[1]) * w + 0.5)
      local g = math.floor(p[2] + (q[2] - p[2]) * w + 0.5)
      local bl = math.floor(p[3] + (q[3] - p[3]) * w + 0.5)
      local colour = (r * 256 + g) * 256 + bl
      local c = nearest[colour]
      if not c then
        local best = math.huge
        for i = 0, 254 do
          local e = rgb[i]
          local d = (e[1] - r) * (e[1] - r) + (e[2] - g) * (e[2] - g) + (e[3] - bl) * (e[3] - bl)
          if d < best then best, c = d, i end
        end
        nearest[colour] = c
      end
      return c
    end
    -- The same with two of the palette's colours.
    local function mix(a, b, w)
      if w >= 1 then return b end
      if a == b or a == 255 or b == 255 then return a end
      return nearestOf(rgb[a], rgb[b], w)
    end
    local rows = look and UIProfessorMenu.MOVIE_ROWS[look]
    -- (How light the board is from each row on.)
    local board = {}
    if rows then
      local percent, i = 100, 1
      for y = 0, PIC_H - 1 do
        while rows.board[i] and y >= rows.board[i] do
          percent, i = rows.board[i + 1], i + 2
        end
        board[y] = percent
      end
    end
    -- (The chart's rows, with its roller and the wall above it.)
    local chart_to = kind == "down" and CHART_BOTTOM or kind == "up" and ROLLER_BOTTOM or -1
    -- The right end's mirror image for fill column `x`, row `y`: on its
    -- paper, where something is drawn (darker than the row's lightest there),
    -- the nearest paper beside it in the row.
    local from = CHART_LEFT + CHART_RIGHT - (BLEND_FROM - 1)
    local to = CHART_RIGHT - EDGE_W
    local function endPaper(x, y)
      local col = CHART_LEFT + CHART_RIGHT - x
      local b = at(col, y)
      if y < END_PAPER_TOP or y > END_PAPER_LOW then return b end
      local paper = 0
      for c = from, to do paper = math.max(paper, bright(at(c, y))) end
      if bright(b) >= paper - 60 then return b end
      for d = 1, to - from do
        for _, c in ipairs({col - d, col + d}) do
          if c >= from and c <= to and bright(at(c, y)) >= paper - 60 then return at(c, y) end
        end
      end
      return b
    end
    -- The blackboard beside the chart's right end (BOARD_FROM to BOARD_TO) is
    -- darker nearer the chart (its shadow): reflected back and forth it made
    -- stripes, and without the chart (rolled up, gone) there is no shadow (Jan,
    -- 2026-11-24). So the plain board is each row's average colour there (the
    -- frame's shadow at the top stays) with the board's grain on it: what each
    -- pixel has beyond its column's and its row's average, a little weaker
    -- (BOARD_GRAIN, as grainy as his movies' board), and taken from another
    -- height for each 20 columns, so that no blotch repeats in a row.
    local BOARD_GRAIN, BOARD_SHIFT = 0.7, 37
    local board_row, board_col = {}, {}
    local board_lo, board_hi = FRAME_BOTTOM + 1, LEDGE_TOP - 1
    do
      local all, cols_n = {0, 0, 0}, BOARD_TO - BOARD_FROM + 1
      for y = board_lo, board_hi do
        local t = {0, 0, 0}
        for s = BOARD_FROM, BOARD_TO do
          local p = rgb[at(s, y)]
          for k = 1, 3 do t[k] = t[k] + p[k] / cols_n end
        end
        board_row[y] = t
        for k = 1, 3 do all[k] = all[k] + t[k] / (board_hi - board_lo + 1) end
      end
      for s = BOARD_FROM, BOARD_TO do
        local t = {0, 0, 0}
        for y = board_lo, board_hi do
          local p = rgb[at(s, y)]
          for k = 1, 3 do t[k] = t[k] + p[k] / (board_hi - board_lo + 1) end
        end
        board_col[s] = {t[1] - all[1], t[2] - all[2], t[3] - all[3]}
      end
    end
    --! The plain board's colour at row `y` with the grain of the picture's
    --! board at column `s`, from the height for fill column `x`'s 20 columns.
    local function boardAt(x, y, s)
      local tile = math.floor((CHART_LEFT + CHART_RIGHT - x - BOARD_FROM) / (BOARD_TO - BOARD_FROM))
      local yy = board_lo + (y - board_lo + BOARD_SHIFT * tile) % (board_hi - board_lo + 1)
      local p, row, col = rgb[at(s, yy)], board_row[y], board_col[s]
      local q = {}
      for k = 1, 3 do q[k] = row[k] + (p[k] - board_row[yy][k] - col[k]) * BOARD_GRAIN end
      return q
    end
    -- Whether the fill's row `y` at column `x` is blackboard without the chart
    -- beside it: then its picture column, evened out (UIProfessorMenu.sideColumn
    -- reflects between BOARD_FROM and BOARD_TO there).
    local function plainBoard(x, y)
      if y <= FRAME_BOTTOM or y >= LEDGE_TOP then return nil end
      if kind ~= "down" and y > ROLLER_BOTTOM then
        return reflect(CHART_LEFT + CHART_RIGHT - x, BOARD_FROM, BOARD_TO)
      end
      local s = UIProfessorMenu.sideColumn(x, y, kind)
      if x < CHART_LEFT and CHART_LEFT + CHART_RIGHT - x > MOUNT_TO then return s end
      return nil
    end
    -- A colour {r, g, b} as the palette's nearest (each part kept to 0-255).
    local function nearestRGB(p)
      return nearestOf({math.max(0, math.min(255, p[1])), math.max(0, math.min(255, p[2])),
          math.max(0, math.min(255, p[3]))}, p, 0)
    end
    -- (Paper at the picture's edge is within PAPER_DARK of its lightest
    -- there; the skeleton's lines and their edges are darker.)
    local PAPER_DARK = 90
    local fill_rows = {}
    for y = 0, PIC_H - 1 do
      pause()
      local paper, lightest
      if kind == "down" and y >= SKELETON_TOP and y <= SKELETON_BOTTOM then
        lightest = 0
        for yy = y - 3, y + 3 do
          for x = 0, EDGE_PAPER - 1 do lightest = math.max(lightest, bright(at(x, yy))) end
        end
        -- The paper's average colour there, grain and all: its commonest was
        -- one of its lightest, a lighter patch beside the skeleton's arm and
        -- feet (Jan, 2026-11-24, "a change of colours near the left foot").
        local found = {}
        for yy = y - 3, y + 3 do
          for x = 0, EDGE_PAPER - 1 do
            local c = at(x, yy)
            if bright(c) >= lightest - PAPER_DARK then found[#found + 1] = c end
          end
        end
        local sum = {0, 0, 0}
        for _, c in ipairs(found) do
          local p = rgb[c]
          for k = 1, 3 do sum[k] = sum[k] + p[k] / #found end
        end
        paper = nearestRGB(sum)
      end
      local line = {}
      for x = -SIDE_W, -1 do
        local c
        local s = plainBoard(x, y)
        if s then
          c = nearestRGB(boardAt(x, y, s))
        else
          c = at(UIProfessorMenu.sideColumn(x, y, kind), y)
        end
        if paper and x >= CHART_LEFT + EDGE_W and bright(c) >= lightest - 60 then
          c = at(-x - 1, y)
          if bright(c) < lightest - 30 then c = paper end
        end
        -- (Left of CHART_LEFT + EDGE_W the fill is the mirror image already.)
        local w = y <= chart_to and x >= CHART_LEFT + EDGE_W and UIProfessorMenu.endBlend(x, y) or 0
        -- (The skeleton's lines stay as they are.)
        if w > 0 and not (paper and bright(c) < lightest - 60) then
          c = mix(c, endPaper(x, y), w)
        end
        line[x] = c
      end
      -- What his movie shows there, from the picture's edge to the chart's end
      -- as the blend at the end goes: its colours with the grain of what the
      -- fill has there (each pixel as far from the row's average as it is;
      -- flat colours made a smooth block beside the wood and the board, Jan
      -- 2026-11-24).
      local seen = rows and rows.left[y - rows.from + 1]
      local mean
      if seen then
        -- (The row's average without the roller's mount: it keeps its own
        -- light and dark against the frame's.)
        mean = {0, 0, 0}
        local n = 0
        for x = rows.reach, -1 do
          local mirror = CHART_LEFT + CHART_RIGHT - x
          if y > FRAME_BOTTOM or mirror < MOUNT_FROM or mirror > MOUNT_TO then
            local p = rgb[line[x]]
            for k = 1, 3 do mean[k] = mean[k] + p[k] end
            n = n + 1
          end
        end
        for k = 1, 3 do mean[k] = mean[k] / n end
      end
      for x = -SIDE_W, -1 do
        local c = line[x]
        if seen and x >= rows.reach then
          -- (Evenly from the picture's edge to the chart's end: the roller's
          -- shadow under it is five rows at the edge and two at its end; going
          -- over within a few columns made a lump, Jan 2026-11-24.)
          local want, p = rows.right and rows.right[y - rows.from + 1] or seen, rgb[c]
          local w = ramp(x, -1, CHART_LEFT + EDGE_W)
          local t = {}
          for k = 1, 3 do t[k] = p[k] - mean[k] + seen[k] + (want[k] - seen[k]) * w end
          c = nearestRGB(t)
        elseif rows and not seen and board[y] ~= 100 then
          -- (The blackboard as light as his movie has it, the whole fill wide.)
          local f = board[y] / 100
          local p = rgb[c]
          c = nearestRGB({p[1] * f, p[2] * f, p[3] * f})
        end
        line[x] = c
      end
      fill_rows[y] = line
    end
    -- In his movies the chart's bottom line is one row (LINE_TOP), as at its
    -- right end, with paper under it; the picture has two at its left (Jan,
    -- 2026-11-24: the corner did not line up).
    if movie and kind == "down" then
      local red, under, paper_row = fill_rows[LINE_TOP], fill_rows[LINE_LOW], fill_rows[LINE_LOW + 1]
      for x = CHART_LEFT + EDGE_W, -1 do
        local p = rgb[under[x]]
        if p[1] > p[2] + 30 then red[x] = under[x] end
        under[x] = paper_row[x]
      end
    end
    local out, n = {}, 0
    for y = 0, PIC_H - 1 do
      for x = -SIDE_W, -1 do
        n = n + 1
        out[n] = CHARS[fill_rows[y][x]]
      end
    end
    -- (Made meanwhile when it was needed before prepare had it.)
    loaded.side_data[data_key] = loaded.side_data[data_key] or table.concat(out)
  end
  if loaded.sides[key] then return loaded.sides[key] end
  local palette = nil
  if light then
    palette = loaded.palettes[light]
    if not palette then
      palette = TH.palette(loaded.pal_data)
      for c = 0, 254 do
        local p = loaded.rgb[c]
        local function lit(v) return math.min(255, math.floor(v * light / 100 + 0.5)) end
        palette:setEntry(c, lit(p[1]), lit(p[2]), lit(p[3]))
      end
      -- (Transparent, as the picture's own palette has it.)
      palette:setEntry(255, 0xFF, 0x00, 0xFF)
      loaded.palettes[light] = palette
    end
  end
  loaded.sides[key] = bitmapOf(app, loaded.side_data[data_key], SIDE_W, palette)
  return loaded.sides[key]
end

--! The picture with a spot pointed at, made the first time (Argus: drawn as
--! one picture, his arm and the pink are as smooth as the rest and line up
--! with it): the chart's writing rubbed out, then his arm pointing at the
--! skull's part, or the skeleton's part pink.
local function view(app, loaded, spot)
  local made = loaded.views[spot.item]
  if made then return made end
  local px = {}
  for i, c in ipairs(loaded.base) do px[i] = c end
  for i, c in pairs(loaded.rubbed) do px[i] = c end
  if spot.arm then
    local arm, at = loaded.arms[spot.arm], ARMS_AT[spot.arm]
    for pos, c in pairs(arm.pixels) do
      local x, y = at[1] + pos % arm.w, at[2] + math.floor(pos / arm.w)
      if x < PIC_W and y < PIC_H then px[y * PIC_W + x + 1] = c end
    end
  else
    local pink_of = loaded.pink_of
    for _, run in ipairs(loaded.pink[spot.item]) do
      for x = run[1], run[1] + run[3] - 1 do
        local i = run[2] * PIC_W + x + 1
        px[i] = pink_of[px[i]]
      end
    end
  end
  local out = {}
  for i, c in ipairs(px) do out[i] = CHARS[c] end
  local bitmap = bitmapOf(app, table.concat(out), PIC_W)
  loaded.views[spot.item] = bitmap
  return bitmap
end

--! Draws the fill at the picture's left, on a screen wider than the picture,
--! with the chart's bottom edge at row `bottom` (CHART_BOTTOM: down, as in
--! the picture; ROLLER_BOTTOM: rolled up), or with the chart and its roller
--! gone (false): what his movies need beside them (MoviePlayer:playMenuMovie).
--! Elsewhere the chart's left end is its rows as his movies have them
--! (UIProfessorMenu.chartRow), while it rolls with the roller's shadow on it
--! as they have it (ROLLING_LIGHT). `top` and `low` (percent, or nil): how light
--! the chart is (lightInMovie); `look` (or nil): what the movie shows behind
--! and under it (lookInMovie); `board` (percent, beside his movies only): how
--! light the blackboard is while the chart is down (boardInMovie).
function UIProfessorMenu.drawSide(canvas, bottom, top, low, look, board)
  local app = TheApp
  local loaded = UIProfessorMenu.art(app)
  if not loaded then return end
  local l = UIProfessorMenu.layout(canvas:getRenderSize())
  if l.px <= 0 then return end
  local movie = board ~= nil
  local down = bottom and bottom >= DOWN_FROM
  local kind = not bottom and "gone" or (down and "down" or "up")
  local fill = side(app, loaded, kind, nil, kind ~= "down" and look or nil, movie)
  if canvas:scale(l.scale) then
    local x, y = l.px - SIDE_W, l.py
    fill:draw(canvas, x, y)
    -- (Clipped to the chart's left end, below the roller.)
    local left = math.max(0, l.px + CHART_LEFT)
    -- Where the renderer scales each drawing (config direct_zoom, the
    -- default), the chart is drawn to the screen's pixel: in his movies its
    -- bottom edge moves a fraction of a row a frame as it springs back.
    -- Otherwise (everything drawn small and then enlarged) to whole rows.
    local fine = not (app.config and app.config.direct_zoom == false)
    local s = l.scale
    -- Clips to the chart's columns, rows `from` up to `to` (not included).
    local function clipRows(from, to)
      if fine then
        canvas:scale(1)
        local x0, y0 = math.floor(left * s + 0.5), math.floor((y + from) * s + 0.5)
        canvas:pushClip(x0, y0, math.floor(l.px * s + 0.5) - x0, math.floor((y + to) * s + 0.5) - y0)
        canvas:scale(s)
      else
        local first = math.floor(from + 0.5)
        canvas:pushClip(left, y + first, l.px - left, math.floor(to + 0.5) - first)
      end
    end
    -- How far the chart as the picture has it is drawn from row `row`.
    local function offset(row)
      local off = UIProfessorMenu.chartRow(row, bottom, true) - row
      if fine then return math.floor(off * s + 0.5) / s end
      return math.floor(off + 0.5)
    end
    -- Its rows `from` to `to` (a fraction where its bottom edge is between
    -- two rows), a band at a time: rows as far from theirs.
    local function chart(from, to, light)
      local picture = side(app, loaded, "down", light, nil, movie)
      local stop = to + 1
      local row = from
      while row < stop do
        local off = offset(row)
        local last = row
        while last + 1 < stop and offset(last + 1) == off do last = last + 1 end
        clipRows(row, math.min(last + 1, stop))
        picture:draw(canvas, x, y - off)
        canvas:popClip()
        row = last + 1
      end
    end
    if bottom and bottom > ROLLER_BOTTOM and bottom ~= CHART_BOTTOM then
      chart(ROLLER_BOTTOM + 1, bottom)
      if not down then
        for _, band in ipairs(rollingBands(bottom)) do chart(band[1], band[2], band[3]) end
      end
    end
    if down and top then
      -- In bands, each as light as the movie has the chart there.
      for row = ROLLER_BOTTOM + 1, bottom, LIGHT_BAND do
        local light = bandLight(row, top, low)
        if light ~= 100 then chart(row, math.min(row + LIGHT_BAND - 1, bottom), light) end
      end
    end
    if down and board and board ~= 100 then
      -- The blackboard beside the chart and under it as light as his movie
      -- has it (Jan, 2026-11-24: a darker block under the chart's corner).
      local lit = side(app, loaded, "down", board, nil, movie)
      local from = math.max(0, x)
      canvas:pushClip(from, y + FRAME_BOTTOM + 1, left - from, LEDGE_TOP - FRAME_BOTTOM - 1)
      lit:draw(canvas, x, y)
      canvas:popClip()
      local under = math.max(bottom, CHART_BOTTOM) + 1
      canvas:pushClip(left, y + under, l.px - left, LEDGE_TOP - under)
      lit:draw(canvas, x, y)
      canvas:popClip()
    end
    if down and bottom < CHART_BOTTOM then
      -- Springing back, what is under the chart's bottom edge when it is down
      -- (its shadow on the blackboard) is as much higher as the edge, drawn on
      -- as the chart's last rows are, not the bare blackboard (Jan 2026-11-25:
      -- a lighter row and a thin line under the corner). It ends UNDER_EDGE
      -- rows lower, blackboard against blackboard.
      clipRows(bottom + 1, CHART_BOTTOM + 1 + UNDER_EDGE)
      side(app, loaded, "down", board ~= 100 and board or nil, nil, movie):draw(canvas, x,
          y - offset(math.ceil(bottom)))
      canvas:popClip()
    end
    canvas:scale(1)
  elseif canvas:scale(l.scale, "bitmap") then
    fill:draw(canvas, l.x - SIDE_W * l.scale, l.y)
    canvas:scale(1)
  else
    fill:draw(canvas, l.x - SIDE_W, l.y)
  end
end

-- The fills UIProfessorMenu.drawSide draws with these (its arguments): a
-- list of side's arguments {kind, light, look, movie} each.
local function fillsOf(bottom, top, low, look, board)
  local movie = board ~= nil
  local down = bottom and bottom >= DOWN_FROM
  local kind = not bottom and "gone" or (down and "down" or "up")
  local fills = {{kind, nil, kind ~= "down" and look or nil, movie}}
  if bottom and bottom > ROLLER_BOTTOM and bottom ~= CHART_BOTTOM then
    fills[#fills + 1] = {"down", nil, nil, movie}
    if not down then
      for _, band in ipairs(rollingBands(bottom)) do fills[#fills + 1] = {"down", band[3], nil, movie} end
    end
  end
  if down and top then
    for row = ROLLER_BOTTOM + 1, bottom, LIGHT_BAND do
      local light = bandLight(row, top, low)
      if light ~= 100 then fills[#fills + 1] = {"down", light, nil, movie} end
    end
  end
  if down and board and board ~= 100 then fills[#fills + 1] = {"down", board, nil, movie} end
  return fills
end

-- (His movies are shorter than this, milliseconds.)
local MOVIES_MS = 15000

--! Every fill drawn beside his movies (UIProfessorMenu.drawSide), each once,
--! in the order they are first needed: as he comes, the menu's own after it,
--! then as he leaves. A list of side's arguments {kind, light, look, movie}.
function UIProfessorMenu.movieFills()
  local fills, seen = {}, {}
  local function add(list)
    for _, f in ipairs(list) do
      local key = UIProfessorMenu.fillKey(f[1], f[2], f[3], f[4])
      if not seen[key] then
        seen[key] = true
        fills[#fills + 1] = f
      end
    end
  end
  for _, leaving in ipairs({false, true}) do
    local n = 0
    while UIProfessorMenu.frameTime(n) < MOVIES_MS do
      local pts = UIProfessorMenu.frameTime(n)
      local top, low = UIProfessorMenu.lightInMovie(leaving, pts)
      add(fillsOf(UIProfessorMenu.chartInMovie(leaving, pts), top, low,
          UIProfessorMenu.lookInMovie(leaving, pts), UIProfessorMenu.boardInMovie(leaving, pts)))
      n = n + 1
    end
    if not leaving then add(fillsOf(CHART_BOTTOM)) end
  end
  return fills
end

--! How long (milliseconds) UIProfessorMenu.prepare goes on a call: as the
--! game draws every 18 milliseconds or so (its timer), 4 made them only 13
--! seconds after his coming movie started, long after he pulled the chart
--! down (Jan 2026-11-25: frames dropped there and as he left; tests had drawn
--! as fast as they could). Longer while the picture stands still
--! (PREPARE_STILL_MS), where a slower drawing does not show.
UIProfessorMenu.PREPARE_MS = 8
UIProfessorMenu.PREPARE_STILL_MS = 30
-- The frames of his coming movie where the picture stands still: the empty
-- blackboard before he peeks in, and after he peeks until he walks in.
local STILL_FRAMES = {{0, 13}, {30, 45}}

--! How long (milliseconds) UIProfessorMenu.prepare may go while his movie
--! (`leaving` or coming) shows frame `frame`.
function UIProfessorMenu.prepareMs(leaving, frame)
  if not leaving then
    for _, still in ipairs(STILL_FRAMES) do
      if frame >= still[1] and frame <= still[2] then return UIProfessorMenu.PREPARE_STILL_MS end
    end
  end
  return UIProfessorMenu.PREPARE_MS
end

-- Making the fills beforehand (UIProfessorMenu.prepare): the coroutine doing
-- it, or false once they are all made.
local preparing = nil

--! Makes the fills drawn beside his movies before they are needed, a little
--! at a time: for about `ms` milliseconds each call (each refresh of his
--! movie, each drawing of the menu), a row of a fill at a time. Made when
--! first drawn, those of his coming took half a second just as he pulled the
--! chart down, and those of his leaving as it rolled up (Jan 2026-11-25: the
--! movie stood still there, then jumped). Nothing where the screen has no
--! fill or the movies are off.
function UIProfessorMenu.prepare(app, ms)
  if preparing == false or not (app and app.video and app.config) or not app.config.movies then
    return
  end
  local loaded = UIProfessorMenu.art(app)
  if not loaded or UIProfessorMenu.layout(app.video:getRenderSize()).px <= 0 then return end
  if not preparing then
    preparing = coroutine.create(function()
      for _, f in ipairs(UIProfessorMenu.movieFills()) do
        pause()
        side(app, loaded, f[1], f[2], f[3], f[4])
      end
    end)
  end
  pause_at = require("sdl").getTicks() + ms
  local ok, err = coroutine.resume(preparing)
  pause_at = nil
  if not ok then
    print("Professor menu: the fills beside his movies were not made beforehand: " .. tostring(err))
    preparing = false
  elseif coroutine.status(preparing) == "dead" then
    preparing = false
  end
end

--! Draws the picture (or `picture`, one made for a spot) to fill the screen,
--! with the fill at its left on a wider screen: the menu's background
--! (UI:draw), and what is pointed at.
function UIProfessorMenu.drawPicture(canvas, picture)
  local loaded = UIProfessorMenu.art(TheApp)
  if not loaded then return end
  picture = picture or loaded.picture
  UIProfessorMenu.drawSide(canvas, CHART_BOTTOM)
  local l = UIProfessorMenu.layout(canvas:getRenderSize())
  if canvas:scale(l.scale) then
    picture:draw(canvas, l.px, l.py)
    canvas:scale(1)
  elseif canvas:scale(l.scale, "bitmap") then
    picture:draw(canvas, l.x, l.y)
    canvas:scale(1)
  else
    picture:draw(canvas, l.x, l.y)
  end
end

local chalk_palettes = {}
-- The blackboard's colour, what the chalk's thinnest strokes fade to.
local BOARD = {20, 24, 24}

--! The ink font (Font51V) in a colour of chalk: the fax's palette with its
--! dark ink that colour and its lighter edges fading to the blackboard's.
--! (A palette for each colour, made once: a sheet is kept for each one.)
local function chalkFont(app, colour)
  local palette = chalk_palettes[colour]
  if not palette then
    local fax = app:readDataFile("QData", "Fax01V.pal")
    palette = TH.palette(fax)
    local want = {colour.red, colour.green, colour.blue}
    for c = 0, 254 do
      local r, g, b = fax:byte(c * 3 + 1, c * 3 + 3)
      local ink = 1 - (r + g + b) / (3 * 63)
      local mix = {}
      for i = 1, 3 do mix[i] = math.floor(BOARD[i] + (want[i] - BOARD[i]) * ink + 0.5) end
      palette:setEntry(c, mix[1], mix[2], mix[3])
    end
    -- (Magenta: transparent, as the game's own palettes have it.)
    palette:setEntry(255, 255, 0, 255)
    chalk_palettes[colour] = palette
  end
  return app.gfx:loadFontAndSpriteTable("QData", "Font51V", false, palette, {ttf_color = colour})
end

--! A text of the game as a string.
local function plain(text)
  if type(text) == "userdata" then text = TH.stringProxy._unwrap(text) end
  return tostring(text)
end

function UIProfessorMenu:UIProfessorMenu(ui)
  self:Window()
  local app = ui.app
  self.ui = ui
  -- The whole screen, in screen pixels; only the spots and the chalk take
  -- clicks.
  self.apply_ui_scale = false
  self.draggable = false
  self.esc_closes = false
  self.modal_class = "main menu"
  self.x, self.y = 0, 0
  self.width, self.height = app.video:getRenderSize()
  self.default_button_sound = "selectx.wav"
  self.label_font = app.gfx:loadFontAndSpriteTable("QData", "Font01V", nil, nil,
      {ttf_color = LABEL_TTF_COL, apply_ui_scale = true})
  self.release_string = app:getReleaseString()
  -- The chart's ink: the fax's font, dark on paper.
  local fax_palette = app.gfx:getPalette("Fax01V.pal")
  self.ink_font = app.gfx:loadFontAndSpriteTable("QData", "Font51V", false, fax_palette)
  self.chalk_font = chalkFont(app, CHALK)
  self.chalk_lit_font = chalkFont(app, CHALK_LIT)
  self.hover = nil -- the spot pointed at
  self.hover_tips = false -- whether the chalk is
  self.pressed = nil
  self.sayings = {}
end

--! The chalk that opens the tips, on the screen: its text, its scale (screen
--! pixels to each of the font's) and its rectangle, at the left of the
--! blackboard's strip under the chart.
function UIProfessorMenu:_chalk()
  local w, h = self.ui.app.video:getRenderSize()
  local chalk = self.chalk_at
  if chalk and chalk.screen_w == w and chalk.screen_h == h then return chalk end
  local l = UIProfessorMenu.layout(w, h)
  local text = plain(_S.main_menu.tips)
  local k = math.max(1, math.floor(l.scale / 2 + 0.5))
  local tw, th = self.chalk_font:sizeOf(text)
  chalk = {screen_w = w, screen_h = h, text = text, k = k,
    x = l.x + CHALK_X * l.scale,
    y = l.y + (CHALK_TOP + CHALK_BOTTOM) / 2 * l.scale - th * k / 2,
    w = tw * k, h = th * k}
  self.chalk_at = chalk
  return chalk
end

--! Whether a point of the screen is on the chalk (give or take a little).
function UIProfessorMenu:onChalk(x, y)
  local chalk = self:_chalk()
  local margin = chalk.k * 3
  return x >= chalk.x - margin and x < chalk.x + chalk.w + margin and
      y >= chalk.y - margin and y < chalk.y + chalk.h + margin
end

--! Whether a window above this one is at the point (no pointing through it).
function UIProfessorMenu:_coveredAt(x, y)
  for _, window in ipairs(self.ui.windows or {}) do
    if window == self then return false end
    local s = window.apply_ui_scale and TheApp.gfx:getUIScale() or 1
    if window.visible and window:hitTest(x - window.x * s, y - window.y * s) then
      return true
    end
  end
  return false
end

--! The spot at a point of the screen, or nil.
function UIProfessorMenu:spotAt(x, y)
  local l = UIProfessorMenu.layout(self.ui.app.video:getRenderSize())
  return UIProfessorMenu.spotAtPicture((x - l.x) / l.scale, (y - l.y) / l.scale)
end

--! What a click at a point would choose: a spot, "tips" (the chalk) or nil.
function UIProfessorMenu:_target(x, y)
  return self:spotAt(x, y) or (self:onChalk(x, y) and "tips") or nil
end

function UIProfessorMenu:hitTest(x, y)
  return self:_target(x, y) ~= nil
end

function UIProfessorMenu:onMouseMove(x, y, dx, dy)
  TheApp:resetIdle()
  local spot, tips = self:spotAt(x, y), self:onChalk(x, y)
  if (spot or tips) and self:_coveredAt(x, y) then spot, tips = nil, false end
  if spot ~= self.hover or tips ~= self.hover_tips then
    self.hover, self.hover_tips = spot, tips
    -- (Argus: the original made a sound for each item pointed at.)
    if spot or tips then
      if self.hover_sound then self.ui:stopSound(self.hover_sound) end
      self.hover_sound = self.ui:playSound(HOVER_SOUND)
    end
    return true
  end
  return false
end

function UIProfessorMenu:onMouseDown(button, x, y)
  if button ~= "left" then return false end
  self.pressed = self:_target(x, y)
  return self.pressed ~= nil
end

function UIProfessorMenu:onMouseUp(button, x, y)
  local pressed = self.pressed
  self.pressed = nil
  if button == "left" and pressed and self:_target(x, y) == pressed then
    if pressed == "tips" then
      self:buttonTips()
    else
      self:choose(pressed)
    end
    return true
  end
  return false
end

--! Does what a spot is for, as its button on the list menu would.
function UIProfessorMenu:choose(spot)
  self.ui:playSound(self.default_button_sound)
  self[spot.button](self)
end

--! The chalk: opens the tips window, or closes it when it is open.
function UIProfessorMenu:buttonTips()
  self.ui:playSound(self.default_button_sound)
  local tips = self.ui:getWindow(UITipOfTheDay)
  if tips then
    tips:close()
  else
    self.ui:addWindow(UITipOfTheDay(self.ui))
  end
end

function UIProfessorMenu:onChangeResolution()
  self.width, self.height = self.ui.app.video:getRenderSize()
  self.sayings = {}
  self.chalk_at = nil
end

--! The professor leaves his chart (the original's movie, MMENU2) before the
--! game ends.
function UIProfessorMenu:buttonExit()
  local app = self.ui.app
  self.ui:addWindow(UIConfirmDialog(self.ui, false, _S.tooltip.main_menu.quit,
    --[[persistable:professor_menu_quit_confirm]] function()
      app.moviePlayer:playMenuMovie(true, function() app:exit() end)
    end))
end

--! A text at the biggest whole scale up to `biggest` (screen pixels to each
--! of the font's) at which it fits across, wrapped, the space he writes in
--! (with its margins, or without them at the same scale), and `max_h` screen
--! pixels down; at the font's own size, with words off its end until it
--! fits.
--!return (table) `text`, `k` (the scale), `x` (where its space starts on the
--! picture), `w` (the width to wrap at, in the font's pixels) and `h` (its
--! height)
local function fit(font, text, f, max_h, biggest)
  local k = math.max(1, math.floor(biggest + 0.5))
  -- (sizeOf gives the last line's width: each word has to fit a line, as a
  -- longer one is not broken.)
  local widest = 0
  for word in text:gmatch("%S+") do
    widest = math.max(widest, (font:sizeOf(word)))
  end
  while true do
    for _, space in ipairs({{TEXT_X, TEXT_W}, {WIDE_X, WIDE_W}}) do
      local w = math.floor(space[2] * f / k)
      local _, h = font:sizeOf(text, w)
      if widest <= w and h * k <= max_h then
        return {text = text, k = k, x = space[1], w = w, h = h}
      end
    end
    if k == 1 then
      -- Too long even at the font's own size (a small screen): words off its
      -- end, also any too wide for a line (the font would draw the rest in
      -- one line, off the chart).
      local w = math.floor(WIDE_W * f)
      local _, h = font:sizeOf(text, w)
      local words = {}
      for word in text:gmatch("%S+") do words[#words + 1] = word end
      local function tooWide()
        for _, word in ipairs(words) do
          if font:sizeOf(word) > w then return true end
        end
        return false
      end
      while #words > 1 and (h > max_h or tooWide()) do
        words[#words] = nil
        text = table.concat(words, " ") .. "..."
        h = select(2, font:sizeOf(text, w))
      end
      return {text = text, k = 1, x = WIDE_X, w = w, h = h}
    end
    k = k - 1
  end
end

--! What he writes for a spot at a picture scale: its name at the biggest
--! scale that fits (up to half the picture's: the font is drawn for screens
--! twice the picture's size), and under it what it does, smaller; the two
--! in the middle of where the chart's writing was, or from its top down
--! when they need more room.
--!return (table) the name and what it does, each as `fit` gives it with its
--! top (`y`, in screen pixels from the picture's)
function UIProfessorMenu:_saying(spot, f)
  local key = spot.item .. "@" .. f
  local saying = self.sayings[key]
  if saying then return saying end
  local font = self.ink_font
  local name = fit(font, plain(_S.main_menu[spot.item]), f, NAME_H * f, f / 2)
  local name_h = name.h * name.k
  local info = fit(font, plain(_S.tooltip.main_menu[spot.item]), f,
      (TEXT_BOTTOM - TEXT_TOP - GAP) * f - name_h, f / 3)
  local block = name_h + GAP * f + info.h * info.k
  local top = TEXT_TOP * f + math.max(0, ((WRITING_BOTTOM - TEXT_TOP) * f - block) / 2)
  name.y = top
  info.y = top + name_h + GAP * f
  saying = {name, info}
  self.sayings[key] = saying
  return saying
end

function UIProfessorMenu:draw(canvas, x, y)
  local app = self.ui.app
  -- (For his leaving, while the menu waits.)
  UIProfessorMenu.prepare(app, UIProfessorMenu.PREPARE_MS)
  local loaded = UIProfessorMenu.art(app)
  local sw = canvas:getRenderSize()
  local spot = self.hover
  if loaded and spot then
    UIProfessorMenu.drawPicture(canvas, view(app, loaded, spot))
    -- What he says, each part in the middle of the space he writes in.
    local l = UIProfessorMenu.layout(canvas:getRenderSize())
    for _, part in ipairs(self:_saying(spot, l.scale)) do
      local k = part.k
      canvas:scale(k)
      self.ink_font:drawWrapped(canvas, part.text, math.floor((l.x + part.x * l.scale) / k),
          math.floor((l.y + part.y) / k), part.w, "center")
      canvas:scale(1)
    end
  end
  if loaded then
    local chalk = self:_chalk()
    local font = self.hover_tips and self.chalk_lit_font or self.chalk_font
    canvas:scale(chalk.k)
    font:draw(canvas, chalk.text, math.floor(chalk.x / chalk.k), math.floor(chalk.y / chalk.k))
    canvas:scale(1)
  end
  -- The version lines, at the top right (on the wall and the blackboard's
  -- frame, clear of the chart), each ending a little before the screen's
  -- edge whatever its length.
  local s = TheApp.gfx:getUIScale()
  local lines = {_S.main_menu.version .. self.release_string}
  if TheApp.config.debug then
    lines[#lines + 1] = _S.main_menu.savegame_version .. TheApp.savegame_version
  end
  if TheApp:isUpdateCheckDisabledByConfig() then
    lines[#lines + 1] = _S.main_menu.updates_off
  end
  for i, line in ipairs(lines) do
    local lw = self.label_font:sizeOf(line)
    self.label_font:draw(canvas, line, sw - 5 * s - lw, (4 + 15 * (i - 1)) * s)
  end
end

return UIProfessorMenu
