--[[ Copyright (c) 2009 Peter "Corsix" Cawley

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

local Window = cth_require("window")
local ipairs
    = ipairs

class "UIJukebox" (Window)

---@class UIJukebox: Window
---@operator call: UIJukebox
local UIJukebox = _G["UIJukebox"] ---@type UIJukebox

-- One column of the jukebox: its width, and the height of a track's row.
local COLUMN_W = 259
local ROW_H = 30

--! How the tracks are laid out: in one column as in the original while they
--! fit on the screen, else in as many columns side by side as it takes (Jan,
--! 2026-11-24: with the new songs the list ran off the screen). The first
--! column has the player's buttons above its tracks; the others start a row
--! higher, beside them, so all columns end at the same height.
--! No more columns than the screen is wide.
--!param count (integer) number of tracks
--!param screen_w (number) the screen's width in UI units
--!param screen_h (number) the screen's height in UI units
--!return columns, rows in the first column
function UIJukebox.layout(count, screen_w, screen_h)
  -- (Header and buttons 77, footer 18, the window's 26 from the top, and a
  -- little room below.)
  local fit = math.max(4, math.floor((screen_h - 77 - 18 - 26 - 6) / ROW_H))
  if count <= fit then return 1, count end
  local columns = 2
  while fit + (columns - 1) * (fit + 1) < count do columns = columns + 1 end
  columns = math.max(1, math.min(columns, math.floor(screen_w / COLUMN_W)))
  -- (As few rows as these columns need.)
  local rows = math.ceil((count - (columns - 1)) / columns)
  return columns, rows
end

function UIJukebox:UIJukebox(app)
  self:Window()
  self.modal_class = "jukebox"
  self.esc_closes = true
  self.audio = app.audio
  self.app = app
  self.ui = app.ui
  local scr_w, scr_h = app.video:getRenderSize()
  local s = app.gfx:getUIScale()
  -- The internet radio is one more row after the tracks (where the engine
  -- can play it).
  local playlist = self.audio.background_playlist
  local entries = #playlist + (self.audio:radioSupported() and 1 or 0)
  local columns, rows = UIJukebox.layout(entries, scr_w / s, scr_h / s)
  self.width = COLUMN_W * columns
  self.height = 74 + ROW_H * rows + 18
  -- (26 from the top left corner as in the original, less where it would not fit.)
  self:setDefaultPosition(math.max(0, math.min(26, math.floor(scr_w / s) - self.width)),
      math.max(0, math.min(26, math.floor(scr_h / s) - self.height)))
  self.panel_sprites = app.gfx:loadSpriteTable("QData", "Req13V", true)
  self.white_font = app.gfx:loadFontAndSpriteTable("QData", "Font01V", nil, nil, { apply_ui_scale = true })
  self.blue_font = app.gfx:loadFontAndSpriteTable("QData", "Font02V", nil, nil, { apply_ui_scale = true })

  -- Dialog head (current track title & exit button)
  self:addPanel(389, 0, 0)
  for x = 30, self.width - 61, 24 do
    self:addPanel(390, x, 0)
  end
  self:addPanel(391, self.width - 61, 0)
  self:addPanel(409, self.width - 42, 19):makeButton(0, 0, 24, 24, 410, self.close):setTooltip(_S.tooltip.jukebox.close)

  self.play_btn =
  self:addPanel(392,   0, 49):makeToggleButton(19, 2, 50, 24, 393, self.togglePlayPause):setSound("selectx.wav"):setTooltip(_S.tooltip.jukebox.play)
  self:updatePlayButton()
  self:addPanel(394,  87, 49):makeButton(0, 2, 24, 24, 395, self.previousTrack):setSound("selectx.wav"):setTooltip(_S.tooltip.jukebox.rewind)
  self:addPanel(396, 115, 49):makeButton(0, 2, 24, 24, 397, self.nextTrack):setSound("selectx.wav"):setTooltip(_S.tooltip.jukebox.fast_forward)
  self:addPanel(398, 157, 49):makeButton(0, 2, 24, 24, 399, self.stopBackgroundTrack):setSound("selectx.wav"):setTooltip(_S.tooltip.jukebox.stop)
  self:addPanel(400, 185, 49):makeButton(0, 2, 24, 24, 401, self.loopTrack):setSound("selectx.wav"):setTooltip(_S.tooltip.jukebox.loop)

  -- Track list: column by column (UIJukebox.layout), each track's row at
  -- self.track_pos[i] = {x, y}.
  self.track_buttons = {}
  self.track_pos = {}
  -- (The lowest track's row of each column, for its footer.)
  local last_y = {}
  local column, row = 0, 0
  for i = 1, entries do
    local info = playlist[i]
    local in_column = column == 0 and rows or rows + 1
    if row >= in_column then column, row = column + 1, 0 end
    local x0 = column * COLUMN_W
    local y = column == 0 and 47 + (row + 1) * ROW_H or 47 + row * ROW_H
    row = row + 1
    last_y[column + 1] = y
    self:addPanel(402, x0, y)
    for x = x0 + 30, x0 + COLUMN_W - 61, 24 do
      self:addPanel(403, x, y)
    end
    if info then
      self.track_pos[i] = {x0, y}
      self.track_buttons[i] = self:addPanel(404, x0 + COLUMN_W - 61, y):makeToggleButton(19, 4, 24, 24, 405):setSound("selectx.wav")
      if not info.enabled then
        self.track_buttons[i]:setToggleState(true)
      end
      self.track_buttons[i].on_click = --[[persistable:jukebox_toggle_track]] function(window)
        window:toggleTrack(i)
      end
    else
      -- The internet radio's row: its name opens the radio window, the
      -- button at its end (pressed while the radio is off, as an
      -- excluded track's) turns it on and off.
      self.radio_pos = {x0, y}
      self:addPanel(0, x0 + 17, y):makeButton(0, 2, 190, 24, 0, self.openRadio)
          :setTooltip(_S.tooltip.jukebox.radio)
      self.radio_button = self:addPanel(404, x0 + COLUMN_W - 61, y)
          :makeToggleButton(19, 4, 24, 24, 405, self.toggleRadio):setSound("selectx.wav")
          :setTooltip(_S.tooltip.jukebox.radio_toggle)
      self.radio_button:setToggleState(not self.audio.radio_on)
    end
  end

  -- Dialog footer, under every column's last track (the last column may be
  -- shorter than the others)
  for c = 1, columns do
    local x0 = (c - 1) * COLUMN_W
    local y = (last_y[c] or 47) + 27
    self:addPanel(406, x0, y)
    for x = x0 + 30, x0 + COLUMN_W - 61, 24 do
      self:addPanel(407, x, y)
    end
    self:addPanel(408, x0 + COLUMN_W - 61, y)
  end

  self:makeTooltip(_S.tooltip.jukebox.current_title, 17, 17, 212, 46)
end

-- makes the play button consistent with the current status of the background music
-- running -> toggled
-- stopped -> not toggled
-- paused  -> not toggled
function UIJukebox:updatePlayButton()
  local audio = self.audio
  local status = (not not audio.background_music and not audio.background_paused)
      or (not not audio.radio_on and not audio.radio_paused)
  if status ~= self.play_btn.toggled then
    self.play_btn:toggle()
  end
  if self.radio_button then
    self.radio_button:setToggleState(not audio.radio_on)
  end
end

function UIJukebox:togglePlayPause()
  if self.audio.radio_on then
    self.audio:pauseRadio()
  elseif not self.audio.background_music then
    -- Update configuration that we want music now.
    self.app.config.play_music = true
    self.app:saveConfig()
    -- (The radio, if that is the chosen music.)
    self.audio:startMusic()
  else
    self.audio:pauseBackgroundTrack()
    -- Just pausing does not imply that the player will want to have music turned off
    -- the next time he or she starts the game.
  end
end

--! The previous or next track: the tracks are the music again, also when
--! the radio played.
function UIJukebox:previousTrack()
  self.audio:chooseTracks()
  self.audio:playPreviousBackgroundTrack()
end

function UIJukebox:nextTrack()
  self.audio:chooseTracks()
  self.audio:playNextBackgroundTrack()
end

--! The radio window: the station's address, Play and Stop.
function UIJukebox:openRadio()
  if not self.ui:getWindow(UIRadio) then
    self.ui:addWindow(UIRadio(self.ui))
  end
end

--! The radio row's button: the radio on (the station played last, or the
--! radio window to choose one) or off (the tracks play again).
function UIJukebox:toggleRadio()
  local audio = self.audio
  if audio.radio_on then
    audio:stopRadio()
    if self.app.config.play_music then
      audio:playRandomBackgroundTrack()
    end
  elseif not (self.app.config.radio_url and audio:playRadio(self.app.config.radio_url)) then
    self:openRadio()
  end
  self:updatePlayButton()
end

function UIJukebox:stopBackgroundTrack()
  -- Pressing this button means that the player doesn't want any
  -- background music in the future, so set that config flag.
  -- (The radio stops too; it stays the chosen music for when music is on.)
  self.app.config.play_music = false
  self.app:saveConfig()
  self.audio:stopBackgroundTrack()
end

function UIJukebox:toggleTrack(index)
  local info = self.audio.background_playlist[index]
  self.track_buttons[index]:setToggleState(info.enabled)
  info.enabled = not info.enabled
  if not info.enabled and self.audio.background_music == info.music then
    self.audio:stopBackgroundTrack()
    self.audio:playRandomBackgroundTrack()
  end
  self.audio:updatePlaylistPreferences()
end

function UIJukebox:loopTrack()
  local index = self.audio:findIndexOfCurrentTrack()
  local playlist = self.audio.background_playlist
  if not playlist[index] then return end

  if playlist[index].loop then
    playlist[index].loop = false

    for i, list_entry in ipairs(playlist) do
      if list_entry.enabled_before_loop and index ~= i then
        list_entry.enabled_before_loop = nil
        self:toggleTrack(i)
      end
    end
  else
    playlist[index].loop = true

    for i, list_entry in ipairs(playlist) do
      if list_entry.enabled and index ~= i then
        list_entry.enabled_before_loop = true
        self:toggleTrack(i)
      end
    end
  end
end

function UIJukebox:draw(canvas, x, y)
  for i, info in ipairs(TheApp.audio.background_playlist) do
    self.track_buttons[i]:setToggleState(not info.enabled)
  end
  local s = TheApp.gfx:getUIScale()
  Window.draw(self, canvas, x, y)
  x, y = self.x * s + x, self.y * s + y

  local playing = self.audio.background_music or ""
  for i, info in ipairs(self.audio.background_playlist) do
    -- (A window from an older save has no track_pos: one column.)
    local pos = self.track_pos and self.track_pos[i] or {0, 47 + i * ROW_H}
    local xpos, ypos = x + pos[1] * s, y + pos[2] * s
    local font = self.white_font
    if info.music == playing then
      font = self.blue_font
    end
    local str = UIJukebox.fitText(font, info.title, 185 * s)
    font:draw(canvas, str, xpos + 24 * s, ypos + 11 * s)
    if info.music == playing then
      font:draw(canvas, str, x + 24 * s, y + 27 * s)
    end
  end

  -- The internet radio: its row says so, or names the station while it
  -- plays (in blue, as a playing track), and so does the top.
  if self.radio_pos then
    local radio = self.audio:getRadioStatus()
    local font = radio and self.blue_font or self.white_font
    local name = _S.radio_window.jukebox_row
    if radio then
      local what = UIRadio.nowPlaying(radio)
      if radio.state == "failed" then
        name = _S.radio_window.jukebox_failed
      elseif what ~= "" then
        name = what
      end
    end
    local str = UIJukebox.fitText(font, name, 185 * s)
    font:draw(canvas, str, x + (self.radio_pos[1] + 24) * s, y + (self.radio_pos[2] + 11) * s)
    if radio then
      font:draw(canvas, str, x + 24 * s, y + 27 * s)
    end
  end
end

--! text shortened with "..." until it is at most width wide in font.
function UIJukebox.fitText(font, text, width)
  local str = text
  while font:sizeOf(str) > width and #str > 3 do
    -- Five bytes off, then back to a whole letter (a station may send
    -- Russian or other letters of several bytes).
    local cut = string.sub(str, 1, #str - (str:sub(-3) == "..." and 8 or 5))
    str = cut:gsub("[\192-\255][\128-\191]*$", "") .. "..."
  end
  return str
end

function UIJukebox:afterLoad(old, new)
  if not self.app.config.audio then
    self:close()
  end
  Window.afterLoad(self, old, new)
  if old < 236 then
    self.white_font = TheApp.gfx:loadFontAndSpriteTable("QData", "Font01V", nil, nil, { apply_ui_scale = true })
    self.blue_font = TheApp.gfx:loadFontAndSpriteTable("QData", "Font02V", nil, nil, { apply_ui_scale = true })
  end
end

return UIJukebox
