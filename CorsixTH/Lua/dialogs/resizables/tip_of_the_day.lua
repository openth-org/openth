--[[ Copyright (c) 2010 Manuel "Roujin" Wolf

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

local UIResizable = cth_require("dialogs.resizable")
local Window = cth_require("window")

--! Tip of the Day Window
class "UITipOfTheDay" (UIResizable)

---@class UITipOfTheDay: UIResizable
---@operator call: UITipOfTheDay
local UITipOfTheDay = _G["UITipOfTheDay"] ---@type UITipOfTheDay

-- The size of the close button.
local close_size = 16

local col_bg = {
  red = math.cosmetic_random(20, 200),
  green = math.cosmetic_random(20, 200),
  blue = math.cosmetic_random(20, 200),
}

-- The multiplayer windows of the main menu (UITipOfTheDay "multiplayer" stays
-- while one of them is open), and their widest (the room view with the
-- assistants' column, dialogs/resizables/multiplayer.lua), the width kept
-- free in the middle when nothing else is known.
local MULTIPLAYER_WINDOWS = {"UIMultiplayer", "UIMultiplayerLevels", "UIMultiplayerRoomOptions",
  "UIMultiplayerDownload", "UILoadMultiplayerGame"}
local MULTIPLAYER_WIDTH = 590
-- Ticks without any of them before the multiplayer tips close (one window
-- replaces another in between).
local MULTIPLAYER_GONE_TICKS = 25

--! The tips (the game's, or the multiplayer ones).
--!param kind (string) optional: "multiplayer"
local function tipsOf(kind)
  return kind == "multiplayer" and _S.multiplayer_tips.tips or _S.totd_window.tips
end

--!param kind (string) optional: "multiplayer" for the multiplayer tips
--! (Argus, 2026-11-22: what a player new to multiplayer should know, at the
--! top of the screen so they see it), shown while the multiplayer windows of
--! the main menu are open (UITipOfTheDay.showMultiplayer).
--!param middle (number) optional: the width of the multiplayer window in the
--! middle of the screen, in UI units (the tips go beside it)
--!param tip_num (integer) optional: the tip to show (else one at random)
function UITipOfTheDay:UITipOfTheDay(ui, kind, middle, tip_num)
  local app = ui.app
  self.kind = kind
  self.middle = middle
  -- If the application window is not wide enough,
  --  the tips window is narrower and taller to fit beside the main menu
  local scr_w = app.video:getRenderSize()
  local width = math.min(380, math.floor(scr_w / 2) - 150)
  local x, y = -20, -20
  -- (The multiplayer tips have a title above the tip.)
  local title_h = 0
  if kind == "multiplayer" then
    title_h = 18
    -- Top right, beside the multiplayer window if there is room; else at
    -- the bottom right, below it.
    local side = math.floor((scr_w / app.gfx:getUIScale() - (middle or MULTIPLAYER_WIDTH)) / 2) - 30
    if side >= 200 then
      width, y = math.min(380, side), 20
    end
  end
  local height = (width > 290 and 110 or 210) + title_h
  self.title_h = title_h
  self:UIResizable(ui, width, height, col_bg)

  self.ui = ui
  self.resizable = false
  self:setDefaultPosition(x, y)
  self.white_font = app.gfx:loadFontAndSpriteTable("QData", "Font01V", nil, nil, { apply_ui_scale = true })
  self.blue_font = app.gfx:loadFontAndSpriteTable("QData", "Font02V", nil, nil, { apply_ui_scale = true })

  self.num_tips = #tipsOf(kind)
  if self.num_tips == 0 then
    -- NB: #_S.totd_window.tips == 0, which implies something went wrong with
    -- the string localisation code, hence don't try to localise the following:
    print("Warning: No tips for tip-of-the-day window")
    self:close()
    return
  end
  self.tip_num = tip_num and math.min(tip_num, self.num_tips) or math.cosmetic_random(1, self.num_tips)

  -- Previous button's y, next button's x, button width
  local function add_nav_buttons(y1, x2, btn_width)
    self:addBevelPanel(10, y1, btn_width, 20, col_bg):setLabel(_S.totd_window.previous)
      :makeButton(0, 0, btn_width, 20, nil, self.buttonPrev):setTooltip(_S.tooltip.totd_window.previous)
    self:addBevelPanel(x2, height - 30, btn_width, 20, col_bg):setLabel(_S.totd_window.next)
      :makeButton(0, 0, btn_width, 20, nil, self.buttonNext):setTooltip(_S.tooltip.totd_window.next)
  end
  if width > 290 then -- The buttons are side by side
    add_nav_buttons(height - 30, math.floor(width / 2) + 10, math.floor(width / 2) - 20)
  else -- The buttons are stacked
    add_nav_buttons(height - 55, 10, width - 20)
  end
  -- A button to close the tips, at the top right corner (the tip is written
  -- beside it).
  self:addBevelPanel(width - close_size - 6, 6, close_size, close_size, col_bg):setLabel("X")
    :makeButton(0, 0, close_size, close_size, nil, self.close)
end

function UITipOfTheDay:draw(canvas, x, y)
  -- Draw window components
  UIResizable.draw(self, canvas, x, y)

  -- Draw tip
  local s = TheApp.gfx:getUIScale()
  x, y = self.x * s + x, self.y * s + y

  local top = 10
  if self.kind == "multiplayer" then
    self.blue_font:draw(canvas, _S.multiplayer_tips.title, x + 10 * s, y + 10 * s)
    top = 10 + (self.title_h or 0)
  end
  local text = tipsOf(self.kind)[self.tip_num]
  self.white_font:drawWrapped(canvas, text, x + 10 * s, y + top * s,
      self.width * s - (20 + close_size) * s)
end

--! The multiplayer tips beside a multiplayer window `middle` wide (UI units),
--! unless the player closed them since the game started (UIMultiplayer opens
--! them). Open already beside a window of another width: moved, the same tip.
function UITipOfTheDay.showMultiplayer(ui, middle)
  if ui.app.multiplayer_tips_closed then return end
  local tip_num
  for _, window in ipairs(ui.windows or {}) do
    if class.is(window, UITipOfTheDay) and window.kind == "multiplayer" then
      if window.middle == middle then return end
      tip_num = window.tip_num
      window.resolution_change = true -- (not the player's X)
      window:close()
    end
  end
  ui:addWindow(UITipOfTheDay(ui, "multiplayer", middle, tip_num))
end

--! The multiplayer tips go when the multiplayer windows have gone (back to
--! the main menu; a game starting brings a new screen anyway).
function UITipOfTheDay:onTick()
  if self.kind == "multiplayer" then
    local open = false
    for _, window in ipairs(self.ui.windows or {}) do
      for _, name in ipairs(MULTIPLAYER_WINDOWS) do
        local klass = _G[name]
        if klass and class.is(window, klass) then open = true end
      end
    end
    self.gone_ticks = open and 0 or (self.gone_ticks or 0) + 1
    if self.gone_ticks > MULTIPLAYER_GONE_TICKS then
      self.closing_by_itself = true
      self:close()
      return
    end
  end
  return UIResizable.onTick(self)
end

--! The player's X on the multiplayer tips: not again until the game restarts.
function UITipOfTheDay:close()
  if self.kind == "multiplayer" and not self.closing_by_itself and not self.resolution_change then
    self.ui.app.multiplayer_tips_closed = true
  end
  return UIResizable.close(self)
end

function UITipOfTheDay:buttonPrev()
  self.tip_num = self.tip_num - 1
  if self.tip_num == 0 then
    self.tip_num = self.num_tips
  end
end

function UITipOfTheDay:buttonNext()
  self.tip_num = self.tip_num + 1
  if self.tip_num > self.num_tips then
    self.tip_num = 1
  end
end

--! Called after the resolution of the game window changes
function UITipOfTheDay:onChangeResolution()
  self.resolution_change = true
  self:close()
  self.ui:addWindow(UITipOfTheDay(self.ui, self.kind, self.middle, self.tip_num))
  Window.onChangeResolution(self)
end

return UITipOfTheDay
