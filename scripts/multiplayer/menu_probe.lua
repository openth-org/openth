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
SOFTWARE.

Usage: CorsixTH --interpreter=<this file> --config-file=<config>
(CORSIXTH_SOURCE: the checkout; MP_SHOT_DIR: [optional] a folder for
screenshots)

The professor's main menu (UIProfessorMenu) at the config's screen size: the
mouse over each spot points at it (screenshots) and what he writes fits its
space, the tips open from the chalk on the blackboard (and close with it and
with their X) and cover no spot, Options opens over the picture and its Back
brings the professor back, and with the setting off the menu is the list,
with the tips open. With movies and the
intro on in the config: first the intro ends, he comes to his chart (his
movie), and when that ends the menu is his. Prints "MENU OK ..." and exits
0, else "MENU FAILED". ]]

local args = {...}
local unpack_args = table.unpack or unpack
local source_dir = assert(os.getenv("CORSIXTH_SOURCE"), "Missing CORSIXTH_SOURCE")
local shot_dir = os.getenv("MP_SHOT_DIR")
assert(loadfile(source_dir .. "/CorsixTH/CorsixTH.lua"))(unpack_args(args))
assert(TheApp.good_install_folder, "Game data was not accepted")

local function fail(why)
  print("MENU FAILED: " .. tostring(why))
  os.exit(1)
end

local size
local function shot(name)
  if not shot_dir then return end
  -- (Twice: a screenshot shows the frame before the last one drawn.)
  TheApp:drawFrame()
  TheApp:drawFrame()
  local path = ("%s/%s-%s.png"):format(shot_dir, size, name)
  local ok, err = TheApp.video:takeScreenshot(path)
  print(ok and ("SHOT " .. path) or ("SHOT FAILED " .. tostring(err)))
end

--! Closes the information windows (a test machine's warnings).
local function closeInformation(ui)
  for i = #(ui.windows or {}), 1, -1 do
    local win = ui.windows[i]
    if class.is(win, UIInformation) then win:close() end
  end
end

local ok, err = pcall(function()
  -- Movies on: the intro is playing. The probe ends each movie as the game
  -- does when one is over (the player's "movie over" event).
  local movies = TheApp.moviePlayer
  if movies.playing then
    local function menu()
      return TheApp.ui and TheApp.ui:getWindow(UIMainMenu)
    end
    assert(not menu(), "a menu during the intro")
    movies:onMovieOver()
    assert(movies.playing, "no movie after the intro")
    assert(not menu(), "the menu came before the professor")
    movies:onMovieOver()
    assert(not movies.playing, "still a movie after the professor came")
    assert(menu() and class.is(menu(), UIProfessorMenu), "no professor menu after his movie")
    print("MOVIES OK: the intro, the professor coming to his chart, his menu")
  end
  local ui = TheApp.ui
  closeInformation(ui)
  local menu = ui:getWindow(UIMainMenu)
  assert(menu and class.is(menu, UIProfessorMenu), "the main menu is not the professor's")
  local w, h = TheApp.video:getRenderSize()
  size = ("%dx%d"):format(w, h)
  -- His movies (coming to the chart, leaving it) found in the game files.
  print(("MOVIES: in %s, out %s"):format(tostring(movies.menu_in_movie), tostring(movies.menu_out_movie)))
  local l = UIProfessorMenu.layout(w, h)
  local f = l.scale
  assert(not ui:getWindow(UITipOfTheDay), "the tips opened with the professor's menu")
  shot("menu")
  local s = TheApp.gfx:getUIScale()
  --! The middle of a spot's outline's corners, on the screen.
  local function middle(spot)
    local sx, sy, n = 0, 0, 0
    for i = 1, #spot.outline - 1, 2 do
      sx, sy, n = sx + spot.outline[i], sy + spot.outline[i + 1], n + 1
    end
    return math.floor(l.x + sx / n * f), math.floor(l.y + sy / n * f)
  end
  local text = UIProfessorMenu.TEXT
  for _, spot in ipairs(UIProfessorMenu.SPOTS) do
    local x, y = middle(spot)
    ui:onMouseMove(x, y, 0, 0)
    assert(menu.hover == spot, ("over %s at %d,%d it points at %s"):format(spot.item, x, y,
        tostring(menu.hover and menu.hover.item)))
    shot(spot.item)
    -- What he writes stays in its space.
    for _, part in ipairs(menu:_saying(spot, f)) do
      local what = ("%s: %q at scale %d"):format(spot.item, part.text, part.k)
      assert(part.w * part.k <= text[3] * f + 0.5, what .. " is too wide")
      assert(part.y >= text[2] * f - 0.5 and part.y + part.h * part.k <= (text[2] + text[4]) * f + 0.5,
          what .. " is out of its space")
      print(("SAYS %s"):format(what))
    end
  end
  -- Away from the chart: nothing.
  ui:onMouseMove(w - 2, h - 2, 0, 0)
  assert(menu.hover == nil, "points at " .. tostring(menu.hover and menu.hover.item))

  -- The chalk: lit under the mouse, opens the tips, which cover no spot and
  -- not the chalk; their X closes them, as does the chalk.
  local chalk = menu:_chalk()
  local cx, cy = math.floor(chalk.x + chalk.w / 2), math.floor(chalk.y + chalk.h / 2)
  assert(chalk.x >= l.x and chalk.y >= l.y + 159 * f and chalk.y + chalk.h <= l.y + 183 * f and
      chalk.y + chalk.h <= h, "the chalk is not on the blackboard under the chart")
  ui:onMouseMove(cx, cy, 0, 0)
  assert(menu.hover_tips and not menu.hover, "the chalk is not lit under the mouse")
  shot("chalk")
  local function click(x, y)
    ui:onMouseDown("left", x, y)
    ui:onMouseUp("left", x, y)
  end
  click(cx, cy)
  local tips = assert(ui:getWindow(UITipOfTheDay), "the chalk did not open the tips")
  local covered = {}
  for _, spot in ipairs(UIProfessorMenu.SPOTS) do
    local x, y = middle(spot)
    if tips:hitTest(x - tips.x * s, y - tips.y * s) then covered[#covered + 1] = spot.item end
  end
  if tips:hitTest(cx - tips.x * s, cy - tips.y * s) then covered[#covered + 1] = "the chalk" end
  assert(#covered == 0, "the tips window is over " .. table.concat(covered, ", "))
  shot("tips")
  local tips_at = ("%d,%d (%dx%d)"):format(tips.x, tips.y, tips.width, tips.height)
  -- Its X, at the top right corner.
  click(math.floor((tips.x + tips.width - 14) * s), math.floor((tips.y + 14) * s))
  assert(not ui:getWindow(UITipOfTheDay), "the X did not close the tips")
  click(cx, cy)
  assert(ui:getWindow(UITipOfTheDay), "the chalk did not open the tips again")
  click(cx, cy)
  assert(not ui:getWindow(UITipOfTheDay), "the chalk did not close the tips")

  -- Options (the small skull) opens over the picture; Back brings him back.
  for _, spot in ipairs(UIProfessorMenu.SPOTS) do
    if spot.item == "options" then menu:choose(spot) end
  end
  local options = assert(ui:getWindow(UIOptions), "no options window")
  assert(not ui:getWindow(UIMainMenu), "the menu stayed under the options")
  assert(ui.professor_background, "the picture went with the menu")
  shot("options-window")
  -- Its Customise window has the switch.
  options:buttonCustomise()
  local customise = assert(ui:getWindow(UICustomise), "no customise window")
  assert(customise.buttons.professor_menu, "no professor menu switch")
  shot("customise-window")
  customise:close()
  local again = ui:getWindow(UIMainMenu)
  assert(again and class.is(again, UIProfessorMenu), "closing Customise did not bring the professor back")
  -- Options again, and its Back.
  again:choose(UIProfessorMenu.SPOTS[#UIProfessorMenu.SPOTS])
  assert(ui:getWindow(UIOptions), "no options window the second time")
  ui:getWindow(UIOptions):buttonBack()
  again = ui:getWindow(UIMainMenu)
  assert(again and class.is(again, UIProfessorMenu), "Back did not bring the professor back")
  assert(ui.windows[#ui.windows] == again, "the professor is not under the other windows")

  -- The setting off: the list menu, on its own background.
  TheApp.config.professor_menu = false
  TheApp:loadMainMenu()
  ui = TheApp.ui
  closeInformation(ui)
  local list = ui:getWindow(UIMainMenu)
  assert(list and not class.is(list, UIProfessorMenu), "not the list menu with the setting off")
  assert(not ui.professor_background, "the professor's picture with the setting off")
  assert(ui:getWindow(UITipOfTheDay), "no tips with the list menu")
  shot("list")
  print(("MENU OK: %s, scale %.2f, corner %d,%d, tips at %s, 10 spots"):format(
      size, f, math.floor(l.x), math.floor(l.y), tips_at))
end)
if not ok then fail(err) end
os.exit(0)
