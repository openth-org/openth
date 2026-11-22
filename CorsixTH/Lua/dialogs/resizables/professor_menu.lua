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

-- The professor's menu is a kind of the list menu: it has the same buttons,
-- and what looks for the main menu finds it too. (Loaded under the name
-- loadLuaFolder gives that file, so it is not run twice.)
if not rawget(_G, "UIMainMenu") then
  corsixth.require("dialogs/resizables" .. package.config:sub(1, 1) .. "main_menu")
end
local UIMainMenu = _G["UIMainMenu"] ---@type UIMainMenu

--! The original game's main menu: the professor at his blackboard, pointing
--! at the parts of the skull on his chart (QData Main01M, a 320x200 picture,
--! and Main02M, his arm pointing at each part, which turns pink). The menu
--! items the original did not have are on the skeleton beside the skull and
--! on the small skull, which turn pink the same way. The name of the item
--! pointed at, and what it does, are written on the chart, where he says it.
--! The picture is the menu's background (UI:setMenuBackground), so it stays
--! behind the windows the menu opens; this window draws what is pointed at.
class "UIProfessorMenu" (UIMainMenu)

---@class UIProfessorMenu: UIMainMenu
---@operator call: UIProfessorMenu
local UIProfessorMenu = _G["UIProfessorMenu"] ---@type UIProfessorMenu

-- The picture's size, and where the pictures of his arm go on it.
local PIC_W, PIC_H = 320, 200
local ARM_X, ARM_Y = 16, 22
-- What stays on the screen when the picture is scaled to fill it: all but
-- the professor's back and the edges of the wall above and below.
local KEEP_W, KEEP_TOP, KEEP_BOTTOM = 300, 2, 182
-- The chart's writing, covered to write on (x, y, width, height): the name in
-- the top part, what it does in the bottom one, and between them the left of
-- the line where his speech mark is (the mark itself is kept).
local NAME_BOX = {124, 58, 46, 21}
local MARK_BOX = {124, 79, 32, 7}
local INFO_BOX = {124, 86, 46, 27}
-- What covers them: the same columns of the chart's blank paper below them
-- (rows 113 to 154 there are blank), the row each copy starts at.
local COVERS = {{NAME_BOX, 113}, {MARK_BOX, 134}, {INFO_BOX, 125}}
-- Where the tips window goes: right of the jaw, under the chart's writing,
-- clear of every spot (none is right of x 100 and below y 120).
local TIPS_LEFT, TIPS_TOP = 101, 120
-- The pink of a part he points at (the paper below shows through as in his
-- pictures).
local PINK = {alpha = 115, red = 133, green = 47, blue = 101}
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
--! left) and the edges of the wall, with black bars where the screen's shape
--! needs more. The corner is a whole number of picture pixels from the
--! screen's, so his arm's pictures (drawn at whole pixels) fit it.
--!return (table) `scale` (screen pixels to each picture pixel), the corner
--! in picture pixels (`px`, `py`) and in screen pixels (`x`, `y`)
function UIProfessorMenu.layout(w, h)
  local f = math.min(math.max(w / PIC_W, h / PIC_H), w / KEEP_W,
      h / (KEEP_BOTTOM - KEEP_TOP))
  local x = PIC_W * f <= w and (w - PIC_W * f) / 2 or 0
  local y = (h - PIC_H * f) / 2
  if PIC_H * f > h then
    y = math.max(math.min(y, h - KEEP_BOTTOM * f), -KEEP_TOP * f)
  end
  local px, py = math.floor(x / f + 0.5), math.floor(y / f + 0.5)
  if py < -KEEP_TOP then py = -KEEP_TOP end
  return {scale = f, px = px, py = py, x = px * f, y = py * f}
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

local art -- false once known that the game files do not have it

--! The professor's pictures from the game files (the demo has them too), or
--! nil without them.
--!return (table) `picture` (the bitmap), `arms` (the sprite sheet) and
--! `pink` (each skeleton spot's paper runs, by item)
function UIProfessorMenu.art(app)
  if art == nil then
    local ok, result = pcall(function()
      local gfx = app.gfx
      local palette = gfx:getPalette("Main01M.pal")
      local loaded = {
        picture = gfx:loadRaw("Main01M", PIC_W, PIC_H, "QData"),
        arms = gfx:loadSpriteTable("QData", "Main02M", true, palette),
        pink = {},
      }
      local pixels = app:readDataFile("QData", "Main01M.dat")
      local colours = app:readDataFile("QData", "Main01M.pal")
      assert(#pixels >= PIC_W * PIC_H and #colours >= 768, "short picture or palette")
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

--! A colour with its alpha for canvas:drawRect (packed as the renderer's
--! palette::pack_argb packs it: red in the lowest byte).
local function argb(c)
  return (((c.alpha or 255) * 256 + c.blue) * 256 + c.green) * 256 + c.red
end

--! Draws the picture to fill the screen (the menu's background, UI:draw).
function UIProfessorMenu.drawPicture(canvas)
  local loaded = UIProfessorMenu.art(TheApp)
  if not loaded then return end
  local l = UIProfessorMenu.layout(canvas:getRenderSize())
  if canvas:scale(l.scale) then
    loaded.picture:draw(canvas, l.px, l.py)
    canvas:scale(1)
  elseif canvas:scale(l.scale, "bitmap") then
    loaded.picture:draw(canvas, l.x, l.y)
    canvas:scale(1)
  else
    loaded.picture:draw(canvas, l.x, l.y)
  end
end

function UIProfessorMenu:UIProfessorMenu(ui)
  self:Window()
  local app = ui.app
  self.ui = ui
  -- The whole screen, in screen pixels; only the spots take clicks.
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
  self.hover = nil
  self.pressed = nil
  self.sayings = {}
end

--! Puts the tips window (UITipOfTheDay) in an empty space (Argus: a window
--! there on its own, as it is now): at the bottom of the screen, right of the
--! skull's jaw, under the chart's writing and over the blackboard, clear of
--! the spots; on a small screen, where it would reach up to them there, at
--! the bottom right, over the professor.
function UIProfessorMenu:placeTips()
  local tips = self.ui:getWindow(UITipOfTheDay)
  if not tips then return end
  local sw, sh = self.ui.app.video:getRenderSize()
  local l = UIProfessorMenu.layout(sw, sh)
  local s = tips.apply_ui_scale and TheApp.gfx:getUIScale() or 1
  local w, h = tips.width * s, tips.height * s
  local x = l.x + TIPS_LEFT * l.scale
  local y = sh - h - 4
  if y < l.y + TIPS_TOP * l.scale then x = sw - w - 4 end
  x = math.max(0, math.min(x, sw - w - 4))
  tips:setPosition(math.floor(x / s), math.floor(math.max(0, y) / s))
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

function UIProfessorMenu:hitTest(x, y)
  return self:spotAt(x, y) ~= nil
end

function UIProfessorMenu:onMouseMove(x, y, dx, dy)
  TheApp:resetIdle()
  local spot = self:spotAt(x, y)
  if spot and self:_coveredAt(x, y) then spot = nil end
  if spot ~= self.hover then
    self.hover = spot
    return true
  end
  return false
end

function UIProfessorMenu:onMouseDown(button, x, y)
  if button ~= "left" then return false end
  self.pressed = self:spotAt(x, y)
  return self.pressed ~= nil
end

function UIProfessorMenu:onMouseUp(button, x, y)
  local pressed = self.pressed
  self.pressed = nil
  if button == "left" and pressed and self:spotAt(x, y) == pressed then
    self:choose(pressed)
    return true
  end
  return false
end

--! Does what a spot is for, as its button on the list menu would.
function UIProfessorMenu:choose(spot)
  self.ui:playSound(self.default_button_sound)
  self[spot.button](self)
end

function UIProfessorMenu:onChangeResolution()
  self.width, self.height = self.ui.app.video:getRenderSize()
  self.sayings = {}
  self:placeTips()
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

--! What is written for a spot at a picture scale: the name in the biggest
--! whole scale (screen pixels to each of the font's) at which it fits its
--! part of the chart, up to half the picture's (the font is drawn for screens
--! twice the picture's size), what it does in a smaller one.
function UIProfessorMenu:_saying(spot, f)
  local key = spot.item .. "@" .. f
  local saying = self.sayings[key]
  if saying then return saying end
  local font = self.ink_font
  local function fit(text, box, biggest)
    if type(text) == "userdata" then text = require("TH").stringProxy._unwrap(text) end
    text = tostring(text)
    local box_w, box_h = box[3] * f, box[4] * f
    local k = math.max(1, math.floor(biggest + 0.5))
    while true do
      local w = math.floor(box_w / k)
      -- (A word longer than the line is not broken: wider than w.)
      local tw, h = font:sizeOf(text, w)
      if tw <= w and h * k <= box_h then
        return {text = text, k = k, w = w, h = h, box = box}
      elseif k == 1 then
        -- Too long even at the font's own size (a small screen): words off
        -- the end until it fits.
        local words = {}
        for word in text:gmatch("%S+") do words[#words + 1] = word end
        while #words > 1 and h > box_h do
          words[#words] = nil
          text = table.concat(words, " ") .. "..."
          h = select(2, font:sizeOf(text, w))
        end
        return {text = text, k = 1, w = w, h = h, box = box}
      end
      k = k - 1
    end
  end
  saying = {
    fit(_S.main_menu[spot.item], NAME_BOX, f / 2),
    fit(_S.tooltip.main_menu[spot.item], INFO_BOX, f / 3),
  }
  self.sayings[key] = saying
  return saying
end

function UIProfessorMenu:draw(canvas, x, y)
  local loaded = UIProfessorMenu.art(self.ui.app)
  local spot = self.hover
  local sw = canvas:getRenderSize()
  if loaded and spot then
    local l = UIProfessorMenu.layout(canvas:getRenderSize())
    local f = l.scale
    if canvas:scale(f) then
      local px, py = l.px, l.py
      if spot.arm then
        loaded.arms:draw(canvas, spot.arm, px + ARM_X, py + ARM_Y)
      else
        local pink = argb(PINK)
        for _, run in ipairs(loaded.pink[spot.item]) do
          canvas:drawRect(pink, px + run[1], py + run[2], run[3], 1)
        end
      end
      for _, cover in ipairs(COVERS) do
        local box = cover[1]
        loaded.picture:draw(canvas, px + box[1], py + box[2], box[1], cover[2], box[3], box[4])
      end
      canvas:scale(1)
      -- What he says: each part in the middle of its box.
      for _, part in ipairs(self:_saying(spot, f)) do
        local k, box = part.k, part.box
        local tx = l.x + box[1] * f
        local ty = l.y + box[2] * f + math.max(0, (box[4] * f - part.h * k) / 2)
        canvas:scale(k)
        self.ink_font:drawWrapped(canvas, part.text, math.floor(tx / k),
            math.floor(ty / k), part.w, "center")
        canvas:scale(1)
      end
    end
  end
  -- The version lines, at the top right (on the wall and the blackboard's
  -- frame, clear of the chart and the tips).
  local s = TheApp.gfx:getUIScale()
  local lines = {_S.main_menu.version .. self.release_string}
  if TheApp.config.debug then
    lines[#lines + 1] = _S.main_menu.savegame_version .. TheApp.savegame_version
  end
  if TheApp:isUpdateCheckDisabledByConfig() then
    lines[#lines + 1] = _S.main_menu.updates_off
  end
  for i, line in ipairs(lines) do
    self.label_font:draw(canvas, line, sw - 205 * s, (4 + 15 * (i - 1)) * s, 200, 0, "right")
  end
end
