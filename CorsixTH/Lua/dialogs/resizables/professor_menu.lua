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
--! screen's.
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
--! pink of each colour), `rubbed` (rubOut's changes) and `views` (the
--! pictures made for the items pointed at, by item)
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
      }
      for i = 1, PIC_W * PIC_H do loaded.base[i] = pixels:byte(i) end
      local rgb = colourTable(colours)
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
  local data = table.concat(out)
  local gfx = app.gfx
  local palette = gfx:getPalette("Main01M.pal")
  local bitmap = TH.bitmap()
  -- (Made again when the renderer is, as the game's pictures are.)
  local function load(bm)
    bm:setPalette(palette)
    assert(bm:load(data, PIC_W, gfx.target))
  end
  load(bitmap)
  gfx.reload_functions[bitmap] = load
  loaded.views[spot.item] = bitmap
  return bitmap
end

--! Draws the picture (or `picture`, one made for a spot) to fill the screen:
--! the menu's background (UI:draw), and what is pointed at.
function UIProfessorMenu.drawPicture(canvas, picture)
  local loaded = UIProfessorMenu.art(TheApp)
  if not loaded then return end
  picture = picture or loaded.picture
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
  -- frame, clear of the chart).
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

return UIProfessorMenu
