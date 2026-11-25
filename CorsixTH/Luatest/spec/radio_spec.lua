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

-- Internet radio in the jukebox (someone asked Jan, 2026-11-25, for a
-- favourite internet radio that the game remembers): the address, which
-- music plays at the start, and what the radio window says.

require("corsixth")
require("class_test_base")

-- The engine's side, recorded: what the game asked of the radio.
local calls = {}
local engine_status = {state = "connecting", station = "", title = "",
  error = "", detail = ""}
local ticks = 0
package.loaded["sdl"] = {
  getTicks = function() return ticks end,
  audio = {
    radioSupported = function() return true end,
    radioPlay = function(url) calls[#calls + 1] = "play " .. url end,
    radioStop = function() calls[#calls + 1] = "stop" end,
    radioPause = function(paused) calls[#calls + 1] = "pause " .. tostring(paused) end,
    radioSetVolume = function() end,
    radioStatus = function() return engine_status end,
    stopMusic = function() calls[#calls + 1] = "stop music" end,
    setMusicVolume = function() end,
  },
}
package.loaded["rnc"] = package.loaded["rnc"] or {}
package.loaded["lfs"] = package.loaded["lfs"] or {}
require("TH")
require("utility")
package.loaded["audio"] = nil
require("audio")
require("window")
require("dialogs/resizable")
require("dialogs/resizables/radio")
require("dialogs/jukebox")

TheApp = TheApp or {}

local Audio = _G["Audio"]
local UIRadio = _G["UIRadio"]
local UIJukebox = _G["UIJukebox"]

-- An Audio with a configuration; the tracks only say they were started.
local function audio_with(config)
  config.audio = true
  config.music_volume = config.music_volume or 0.5
  local app = {config = config, saves = 0}
  function app.saveConfig() app.saves = app.saves + 1 end
  local audio = Audio(app)
  audio.background_playlist = {}
  audio.tracks_started = 0
  function audio:playRandomBackgroundTrack()
    self.tracks_started = self.tracks_started + 1
  end
  for k in pairs(calls) do calls[k] = nil end
  return audio, app
end

describe("Internet radio address", function()
  it("is cleaned up as typed or pasted", function()
    assert.equal("http://stream.example.org/live.mp3",
        Audio.cleanRadioAddress("  stream.example.org/live.mp3 \r\n"))
    assert.equal("https://example.org/radio.pls",
        Audio.cleanRadioAddress("https://example.org/radio.pls"))
    assert.equal("", Audio.cleanRadioAddress("   "))
    assert.equal("", Audio.cleanRadioAddress(nil))
  end)
end)

describe("Internet radio in the game", function()
  it("plays instead of the tracks and is remembered", function()
    local audio, app = audio_with({play_music = true})
    assert.is_true(audio:playRadio(" example.org/live.mp3"))
    assert.equal("http://example.org/live.mp3", app.config.radio_url)
    assert.is_true(app.config.radio_on)
    assert.is_true(audio.radio_on)
    assert.equal("play http://example.org/live.mp3", calls[#calls])
    assert.equal(0, audio.tracks_started)
  end)

  it("starts with the game when it was on, else the tracks do", function()
    local audio = audio_with({play_music = true, radio_on = true,
      radio_url = "http://example.org/live.mp3"})
    audio:startMusic()
    assert.is_true(audio.radio_on)
    assert.equal(0, audio.tracks_started)

    audio = audio_with({play_music = true, radio_on = false,
      radio_url = "http://example.org/live.mp3"})
    audio:startMusic()
    assert.is_nil(audio.radio_on)
    assert.equal(1, audio.tracks_started)

    audio = audio_with({play_music = false, radio_on = true,
      radio_url = "http://example.org/live.mp3"})
    audio:startMusic()
    assert.is_nil(audio.radio_on)
    assert.equal(0, audio.tracks_started)
  end)

  it("gives way to the tracks when the station fails at the start, and stays chosen", function()
    local audio, app = audio_with({play_music = true, radio_on = true,
      radio_url = "http://example.org/gone.mp3"})
    audio:startMusic()
    engine_status = {state = "failed", station = "", title = "",
      error = "open", detail = "404"}
    ticks = ticks + 1000
    audio:radioTick()
    assert.is_nil(audio.radio_on)
    assert.equal(1, audio.tracks_started)
    assert.is_true(app.config.radio_on, "the radio stays the chosen music")
  end)

  it("does not give way once it played", function()
    local audio = audio_with({play_music = true})
    audio:playRadio("http://example.org/live.mp3", true)
    engine_status = {state = "playing", station = "Example FM", title = "",
      error = "", detail = ""}
    ticks = ticks + 1000
    audio:radioTick()
    engine_status = {state = "failed", station = "", title = "",
      error = "ended", detail = ""}
    ticks = ticks + 1000
    audio:radioTick()
    assert.is_true(audio.radio_on)
    assert.equal("failed", audio:getRadioStatus().state)
    assert.equal(0, audio.tracks_started)
  end)

  it("music off stops it but keeps it chosen; stopping it chooses the tracks", function()
    local audio, app = audio_with({play_music = true})
    audio:playRadio("http://example.org/live.mp3")
    audio:stopBackgroundTrack()
    assert.is_nil(audio.radio_on)
    assert.is_true(app.config.radio_on)
    audio:playRadio("http://example.org/live.mp3")
    audio:stopRadio()
    assert.is_false(app.config.radio_on)
  end)

  it("pauses and resumes", function()
    local audio = audio_with({play_music = true})
    audio:playRadio("http://example.org/live.mp3")
    assert.is_true(audio:pauseRadio())
    assert.equal("pause true", calls[#calls])
    assert.is_false(audio:pauseRadio())
    assert.equal("pause false", calls[#calls])
  end)
end)

describe("Radio window texts", function()
  _S = _S or {}
  _S.radio_window = {status_off = "off", status_connecting = "connecting",
    status_playing = "Playing", status_paused = "paused",
    error_open = "cannot open", error_https = "no https",
    not_supported = "not here"}

  it("names the station and the song", function()
    assert.equal("Example FM: Artist - Song",
        UIRadio.nowPlaying({station = "Example FM", title = "Artist - Song"}))
    assert.equal("Artist - Song", UIRadio.nowPlaying({station = "", title = "Artist - Song"}))
    assert.equal("Example FM", UIRadio.nowPlaying({station = "Example FM", title = ""}))
    assert.equal("", UIRadio.nowPlaying({station = "", title = ""}))
  end)

  it("says what the radio does", function()
    local audio = audio_with({play_music = true})
    assert.equal("off", UIRadio.statusText(audio))
    audio:playRadio("https://example.org/live.mp3")
    engine_status = {state = "failed", station = "", title = "",
      error = "https", detail = "Protocol not found"}
    ticks = ticks + 1000
    audio:radioTick()
    assert.equal("no https", UIRadio.statusText(audio))
    engine_status = {state = "failed", station = "", title = "",
      error = "something new", detail = ""}
    ticks = ticks + 1000
    audio:radioTick()
    assert.equal("cannot open", UIRadio.statusText(audio))
    engine_status = {state = "playing", station = "Example FM", title = "",
      error = "", detail = ""}
    ticks = ticks + 1000
    audio:radioTick()
    assert.equal("Playing: Example FM", UIRadio.statusText(audio))
  end)
end)

describe("Jukebox text that does not fit", function()
  -- (A font of 7 pixels a byte.)
  local font = {sizeOf = function(_, s) return #s * 7 end}

  -- Whether s is whole UTF-8 letters (no letter cut in half).
  local function whole_letters(s)
    local i = 1
    while i <= #s do
      local b = s:byte(i)
      local n = b < 0x80 and 0 or b >= 0xF0 and 3 or b >= 0xE0 and 2 or b >= 0xC0 and 1 or -1
      if n < 0 then return false end
      for k = 1, n do
        local c = s:byte(i + k)
        if not c or c < 0x80 or c >= 0xC0 then return false end
      end
      i = i + n + 1
    end
    return true
  end

  it("is shortened to whole letters", function()
    for cut = 0, 6 do
      local name = string.rep("Радио Москва ", 4):sub(1 + cut)
      if whole_letters(name) then
        local str = UIJukebox.fitText(font, name, 100)
        assert.is_true(#str * 7 <= 100)
        assert.equal("...", str:sub(-3))
        assert.is_true(whole_letters(str), str)
      end
    end
  end)

  it("leaves text that fits alone", function()
    assert.equal("Radio", UIJukebox.fitText(font, "Radio", 100))
  end)

  it("is shortened when it is one of the game's texts", function()
    -- (_S gives the jukebox a game text, which is no Lua string: a long
    -- one, Dutch "Internetradio: niet beschikbaar", stopped the jukebox.
    -- io.stdout stands in for such a text here.)
    local TH = require("TH")
    local old_proxy = TH.stringProxy
    TH.stringProxy = {_unwrap = function(text)
      if text == io.stdout then return "Internetradio: niet beschikbaar" end
      return text
    end}
    local ok, str = pcall(UIJukebox.fitText, font, io.stdout, 100)
    TH.stringProxy = old_proxy
    assert.is_true(ok, tostring(str))
    assert.is_true(#str * 7 <= 100)
    assert.equal("Internetrad...", str)
  end)
end)

describe("Address box shortened at the front", function()
  -- (A font of 7 pixels a byte that notes every text it measures.)
  local measured = {}
  local font = {
    sizeOf = function(_, s) return #s * 7 end,
    draw = function(_, _, s)
      measured[#measured + 1] = s
      return 0, #s * 7
    end,
  }
  local box = {label_font = font, auto_clip = "start"}
  local Panel = _G["Panel"]

  it("shows the end of a long address, never from a \"/\"", function()
    local address = "http://ice1.somafm.com/groovesalad-128-mp3"
    -- (Typed again on the end of the remembered address, as it happens.)
    local line = address .. address
    for limit = 100, 400, 7 do
      for k in pairs(measured) do measured[k] = nil end
      local str = Panel.clipLine(box, line, limit)
      assert.equal("...", str:sub(1, 3))
      assert.is_true(line:sub(-(#str - 3)) == str:sub(4), str)
      -- "//" first is a paragraph break in the game's texts (and the
      -- Unicode font misread one at the very start of a text).
      assert.is_true(str:sub(4, 4) ~= "/", str)
      for _, s in ipairs(measured) do
        assert.is_true(s:sub(1, 1) ~= "/", s)
      end
    end
  end)
end)
