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

--! Jukebox > Internet radio: the address of a station (typed, or pasted
--! with Ctrl+V), Play and Stop, and what the station plays now. The game
--! remembers the address (config radio_url) and, while the radio is on,
--! plays it instead of the music tracks, now and when the game starts again.
--! Only this computer hears it: nothing goes to a multiplayer game.
class "UIRadio" (UIResizable)

---@class UIRadio: UIResizable
---@operator call: UIRadio
local UIRadio = _G["UIRadio"] ---@type UIRadio

local col = {
  bg = Colours.PanelDefault,
  title = Colours.Title,
  textbox = Colours.Textbox,
}

local W, H = 440, 165
local BUTTON_W = math.floor((W - 60) / 3)

--! The font for an address and a station's words: the game's own font has
--! no "/", "[" or "]", so the Unicode font at its size, when the game has
--! one (nil: the panel's usual font).
local function exactFont()
  local gfx = TheApp.gfx
  if not gfx.ttf_font_data then return nil end
  return gfx:loadLanguageFont("unicode", gfx:loadSpriteTable("QData", "Font01V"),
      {ttf_shadow = true, apply_ui_scale = true})
end

function UIRadio:UIRadio(ui)
  local S = _S.radio_window
  self:UIResizable(ui, W, H, col.bg)
  self.app = ui.app
  self.audio = ui.app.audio
  self.resizable = false
  self.on_top = true
  self.esc_closes = true
  self:setDefaultPosition(0.5, 0.35)
  self.default_button_sound = "selectx.wav"
  self:addBevelPanel(20, 10, W - 40, 20, col.title):setLabel(S.caption).lowered = true
  self.address_box = self:addBevelPanel(20, 40, W - 40, 25, col.textbox, col.bg, col.bg)
    :setAutoClip("start")
    :makeTextbox(--[[persistable:radio_address_confirm]] function() self:buttonPlay() end,
        --[[persistable:radio_address_abort]] function() end)
    :allowedInput("all"):setText(self.app.config.radio_url or "")
  self.address_box.panel:setTooltip(_S.tooltip.radio_window.address)
  local font = exactFont()
  if font then self.address_box.panel:setLabel(self.address_box.text, font) end
  -- What the radio does: two lines of room for a station's name and song.
  self.status_panel = self:addBevelPanel(20, 72, W - 40, 34, col.bg)
  self.status_panel.lowered = true
  self.status_panel.wrap_text = true
  if font then self.status_panel:setLabel("", font) end
  self:addBevelPanel(20, 117, BUTTON_W, 30, col.bg):setLabel(S.play)
    :makeButton(0, 0, BUTTON_W, 30, nil, self.buttonPlay):setTooltip(_S.tooltip.radio_window.play)
  self:addBevelPanel(30 + BUTTON_W, 117, BUTTON_W, 30, col.bg):setLabel(S.stop)
    :makeButton(0, 0, BUTTON_W, 30, nil, self.buttonStop):setTooltip(_S.tooltip.radio_window.stop)
  self:addBevelPanel(40 + 2 * BUTTON_W, 117, BUTTON_W, 30, col.bg):setLabel(S.close)
    :makeButton(0, 0, BUTTON_W, 30, nil, self.close)
  self:updateStatus()
  if not self.audio.radio_on and self.audio:radioSupported() then
    self.address_box:setActive(true)
  end
end

--! What a station sends about itself and the song: "Station: Song", or
--! whichever of the two it sends.
--!param status (table) the radio's status (Audio:getRadioStatus)
--!return (string) "" when it sends neither
function UIRadio.nowPlaying(status)
  local station, title = status.station or "", status.title or ""
  if station ~= "" and title ~= "" and title ~= station then
    return station .. ": " .. title
  end
  return title ~= "" and title or station
end

--! The line under the address: off, connecting, playing what, or why the
--! station could not be played.
function UIRadio.statusText(audio)
  local S = _S.radio_window
  if not audio:radioSupported() then return S.not_supported end
  local status = audio:getRadioStatus()
  if not status then return S.status_off end
  if audio.radio_paused then return S.status_paused end
  if status.state == "playing" then
    local what = UIRadio.nowPlaying(status)
    return what ~= "" and (S.status_playing .. ": " .. what) or S.status_playing
  elseif status.state == "failed" then
    return S["error_" .. (status.error or "")] or S.error_open
  end
  return S.status_connecting
end

function UIRadio:updateStatus()
  -- (New text only when the radio's state changed.)
  local audio = self.audio
  local s = audio:getRadioStatus() or {}
  local key = table.concat({tostring(audio:radioSupported()), tostring(audio.radio_on),
    tostring(audio.radio_paused), s.state or "", s.station or "", s.title or "",
    s.error or ""}, "|")
  if key ~= self.status_key then
    self.status_key = key
    self.status_panel:setLabel(UIRadio.statusText(audio))
  end
end

function UIRadio:onTick()
  self.ticks = (self.ticks or 0) + 1
  if self.ticks % 10 == 0 then self:updateStatus() end
  return UIResizable.onTick(self)
end

function UIRadio:buttonPlay()
  local text = self.address_box.text
  if type(text) == "table" then text = table.concat(text, "") end
  local url = Audio.cleanRadioAddress(text)
  if url == "" or not self.audio:radioSupported() then
    if not self.address_box.active then self.address_box:setActive(true) end
    return
  end
  if self.address_box.active then self.address_box:setActive(false) end
  self.address_box:setText(url)
  self.audio:playRadio(url)
  self:updateStatus()
end

--! The radio off: the game's tracks are the music again (if music is on).
function UIRadio:buttonStop()
  local was_on = self.audio.radio_on
  self.audio:stopRadio()
  self.audio:chooseTracks()
  if was_on and self.app.config.play_music then
    self.audio:playRandomBackgroundTrack()
  end
  self:updateStatus()
end

function UIRadio:afterLoad(old, new)
  UIResizable.afterLoad(self, old, new)
  -- (The radio's state is this computer's, not the saved game's.)
  self.status_key = nil
end
