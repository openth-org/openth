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

-- Do the menu windows' labels fit their buttons? Run through the CorsixTH
-- executable with --interpreter=<this file> and a config file with the
-- language and the menu_font to check: the main menu (with the tips), the
-- Settings windows, New Game, Load Game and the custom game lists are opened
-- one by one and every one-line label is measured with its own font against
-- its panel (4 UI units less: the bevel), at the config's UI scale.
--   CORSIXTH_SOURCE  checkout root (required)
--   MP_SHOT_DIR      optional: a screenshot of each window there, named
--                    <MP_TAG>-<window>.png
-- Prints "OVER <width>/<room> <window>: <text>" and "LABEL FIT: n of m over";
-- exits 1 if any is over.
local args = {...}
local unpack_args = table.unpack or unpack
local source_dir = assert(os.getenv("CORSIXTH_SOURCE"))
local shot_dir, tag = os.getenv("MP_SHOT_DIR"), os.getenv("MP_TAG") or "x"
assert(loadfile(source_dir .. "/CorsixTH/CorsixTH.lua"))(unpack_args(args))
local ui = TheApp.ui
TheApp.config.professor_menu = false
for i = #(ui.windows or {}), 1, -1 do ui.windows[i]:close() end
ui:setMenuBackground()
ui:openMainMenu()
local over, total = 0, 0

local function text_of(label)
  return (tostring(label):gsub("^<LocalisedString> Current value:", ""))
end

local function check(window, name)
  for _, p in ipairs(window.panels or {}) do
    local l = p.label
    if l and p.label_font and type(l) ~= "table" and not p.auto_clip and not p.wrap_text
        and p.visible ~= false and text_of(l) ~= "" then
      total = total + 1
      local w = p.label_font:sizeOf(l)
      local room = (p.w - 4) * TheApp.gfx:getUIScale()
      if w > room then
        over = over + 1
        print(("OVER %3d/%3d %s: %s"):format(w, room, name, text_of(l)))
      end
    end
  end
  for _, sub in ipairs(window.windows or {}) do check(sub, name .. ">sub") end
end

local function shot(name)
  if not shot_dir then return end
  TheApp:drawFrame() TheApp:drawFrame()
  TheApp.video:takeScreenshot(("%s/%s-%s.png"):format(shot_dir, tag, name))
end

local function try(name, make)
  local ok, w = pcall(make)
  if not ok then print("ERROR " .. name .. ": " .. tostring(w)) return end
  if w then ui:addWindow(w) end
  for _, win in ipairs(ui.windows) do check(win, name .. ":" .. (class.type and class.type(win) or "?")) end
  shot(name)
  if w then pcall(UIResizable.close, w) end
end

try("menu", function()
  ui:addWindow(UITipOfTheDay(ui))
  return nil
end)
local function req(m) return cth_require(m) end
try("options", function() return UIOptions(ui, "menu") end)
try("customise", function() return req("dialogs.resizables.customise")(ui, "menu") end)
try("folder", function() return req("dialogs.resizables.folder_settings")(ui, "menu") end)
try("sound", function() return req("dialogs.resizables.sound_setting")(ui, "menu") end)
try("graphics", function() return req("dialogs.resizables.graphics_settings")(ui, "menu") end)
try("accessibility", function() return req("dialogs.resizables.menu_list_dialogs.accessibility")(ui, "menu") end)
try("hotkeys", function() return req("dialogs.resizables.hotkey_assign")(ui, "menu") end)
try("new_game", function() return req("dialogs.resizables.new_game")(ui) end)
try("load_game", function() return UILoadGame(ui, "menu") end)
try("custom_campaign", function() return req("dialogs.resizables.menu_list_dialogs.custom_campaign")(ui) end)
try("custom_game", function() return req("dialogs.resizables.menu_list_dialogs.custom_game")(ui) end)
try("quit", function() return UIConfirmDialog(ui, false, _S.confirmation.quit, function() end) end)
print(("LABEL FIT: %d of %d over"):format(over, total))
io.stdout:flush()
os.exit(over == 0 and 0 or 1)
