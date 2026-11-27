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

-- Do multiplayer texts fit where they are drawn? Run through the CorsixTH
-- executable with --interpreter=<this file> and a config file whose language
-- is the one to check: every text in the list below is measured with the
-- panels' label font (the game's own, with the Unicode font for letters it
-- lacks) and compared with the width of the panel it goes in.
--   CORSIXTH_SOURCE  checkout root (required)
-- Prints "FIT <width>/<room> <key>: <text>" or "OVER ..."; exits 1 if any is over.

local args = {...}
local unpack_args = table.unpack or unpack
local source_dir = assert(os.getenv("CORSIXTH_SOURCE"), "Missing CORSIXTH_SOURCE")
assert(loadfile(source_dir .. "/CorsixTH/CorsixTH.lua"))(unpack_args(args))

local S = _S.multiplayer_window
local mb = function(n) return S.megabytes:format(n) end
-- {key, the text as drawn, the panel's width} (a few pixels less than the
-- panel: the label is drawn inside its bevel). Widths from the dialogs:
-- multiplayer.lua (WIDTH 420, the assistants' column 70), multiplayer_download.lua (400),
-- multiplayer_save.lua (360), multiplayer_levels.lua (600).
local list = {
  {"get_version", S.get_version:format(mb("3.3")), 374},
  {"switch_version", S.switch_version, 374},
  {"version_other", S.version_other, 374},
  {"version_newer_game", S.version_newer_game, 374},
  {"version_caption", S.version_caption, 354},
  {"version_downloading", S.version_downloading:format(mb("1.7"), mb("3.3")), 354},
  {"version_checking", S.version_checking, 354},
  {"version_starting", S.version_starting, 354},
  {"version_failed", S.version_failed:format("timeout"), 354},
  {"version_bad", S.version_bad, 354},
  {"version_cancel", S.version_cancel, 134},
  {"version_close", S.version_close, 134},
  {"save_caption", S.save_caption, 314},
  {"save_button", S.save_button, 149},
  {"room_map", S.room_map, 64},
  {"room_map_caption", S.room_map_caption, 554},
  {"assistants_caption", S.assistants_caption, 76},
  {"assistant_yes", S.assistant_yes, 76},
  {"assistant_no", S.assistant_no, 76},
  -- The room list's Start new game (two buttons of 185, or one of 345 with
  -- the x) and its message line.
  {"new_game_caption", S.new_game_caption, 374},
  {"select_level", S.select_level, 179},
  {"load_game", S.load_game, 179},
  -- (Every multiplayer level's, below: the longest. A longer one would end
  -- its map's name in "...".)
  {"choose_level_first", S.choose_level_first, 374},
  -- A place's menu is at most as wide as the place's line.
  {"add_assistant", S.add_assistant, 374},
  {"add_assistant_for", S.add_assistant_for:format("MATROFTT"), 374},
  {"remove_assistant", S.remove_assistant, 374},
  -- The connect view's server buttons (two to a row; EU2 alone on the
  -- second row has the whole row) and Discord button.
  {"server_eu1", S.server_eu1, 113},
  {"server_us1", S.server_us1, 113},
  {"server_eu2", S.server_eu2, 241},
  {"discord", S.discord, 126},
  -- The plot hand-over window (multiplayer_plot.lua, WIDTH 380): what is
  -- sold with the plot.
  {"plot_give_sold_line", S.plot_give_sold_line:format(12, 34), 334},
  -- The main menu's last row: Discord (64 wide) and Exit (88).
  {"main_menu.discord", _S.main_menu.discord, 60},
  {"main_menu.exit", _S.main_menu.exit, 84},
  -- The Customise window's labels are 165 wide: the professor menu switch.
  {"customise_window.professor_menu", _S.customise_window.professor_menu, 160},
}

-- The room's lines (multiplayer.lua _buildRoom): a place's line is 270 wide
-- (Jan, 2026-11-27: "waiting for a player... (click: add a bot)" ran out of
-- it in Press Start 2P), the speed and the hint 380, the mode 305 (the Map
-- button beside it).
do
  local function room_list(key, text, room) list[#list + 1] = {key, text, room} end
  room_list("add_bot", S.add_bot, 264)
  room_list("waiting_player", S.waiting_player, 264)
  room_list("bot_starting", S.bot_starting, 264)
  room_list("player_line host", S.player_line:format("MATROFTT", S.owner_mark, "307", ""), 264)
  room_list("player_line", S.player_line:format("MATROFTT", "", "307", S.not_ready), 264)
  room_list("bot_named", S.bot_named:format("Bot Florence", S.bot_kind_normal), 264)
  room_list("room_hint", S.room_hint, 374)
  room_list("measuring", S.measuring, 374)
  for _, speed in ipairs({"Slowest", "Slower", "Normal", "Max speed", "And then some more"}) do
    room_list("recommendation " .. speed, S.recommendation:format(MultiplayerLobby.speedName(speed), "270"), 374)
  end
  for _, mode in ipairs({"shared", "coop", "competitive", "teams", "teamshared", "mixed"}) do
    room_list("mode " .. mode, MultiplayerLobby.modeLabel(mode) .. ", " .. S.level:format(12), 299)
  end
end

-- The Start new game button with each multiplayer level chosen.
do
  local levels = corsixth.require("mp_levels")
  for level = 1, levels.COUNT do
    local max = math.min(8, levels.maxHospitals(level))
    list[#list + 1] = {"level_chosen " .. level,
        S.level_chosen:format(level, UIMultiplayerLevels.nameOf(level, false, max), max), 339}
  end
end

local font = TheApp.gfx:loadFontAndSpriteTable("QData", "Font01V", nil, nil, {ttf_shadow = true, apply_ui_scale = true})
local over = 0
for _, item in ipairs(list) do
  -- (The font takes the localised string itself; tostring() would add the
  -- proxy's "<LocalisedString> Current value:" for the print only.)
  -- (The widths are UI units, the text's pixels: at UI scale 2 twice as many.)
  local key, room = item[1], item[3] * TheApp.gfx:getUIScale()
  local w = font:sizeOf(item[2])
  local text = tostring(item[2]):gsub("^<LocalisedString> Current value:", "")
  if w > room then over = over + 1 end
  io.stdout:write(string.format("%s %3d/%3d %s: %s\n", w > room and "OVER" or "FIT ", w, room, key, text))
end
io.stdout:write(string.format("TEXT FIT: %d of %d over\n", over, #list))
io.stdout:flush()
os.exit(over == 0 and 0 or 1)
