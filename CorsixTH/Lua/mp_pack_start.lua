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

--! Run by CorsixTH.lua before anything else (plain Lua, no game classes yet):
--! which downloaded build of the game (mp_pack.lua) starts instead of the
--! installed one. Arguments: the installed game's folder, its Lua folder and
--! the command line. Returns that build's CorsixTH.lua and the arguments to
--! add to the command line, or nil to start the installed game.
--!
--! builds/current.txt (beside the config file) names the build. A start of it
--! that never reached the main menu leaves builds/starting.txt behind; then
--! the installed game starts instead, and goes on doing so until a build is
--! chosen again.
--!
--! builds/installed.txt holds the Lua checksum of the game that was installed
--! when the build was chosen. Once another game is installed (a new download
--! of OpenTH), that game starts itself instead (Jan, 2026-11-25: a new
--! download kept running the build chosen in the old one).

local base_dir, code_dir = ...
local args = {select(3, ...)}
local pathsep = package.config:sub(1, 1)

local config_file, hotkeys_file
for _, arg in ipairs(args) do
  if arg:match("^%-%-pack%-of=") or arg == "--installed-game" then
    return nil -- (this is a downloaded build already, or the player asked)
  end
  config_file = arg:match("^%-%-config%-file=(.*)$") or config_file
  hotkeys_file = arg:match("^%-%-hotkeys%-file=(.*)$") or hotkeys_file
end
if not config_file or not hotkeys_file then
  local finder = assert(loadfile(code_dir .. "config_finder.lua"))()
  config_file = config_file or finder.config_filename
  hotkeys_file = hotkeys_file or finder.hotkeys_filename
end

local builds = (config_file:match("^(.*[/\\])") or "") .. "builds" .. pathsep
local function read(name)
  local f = io.open(builds .. name, "rb")
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  return text
end

local function write(name, text)
  local f = io.open(builds .. name, "wb")
  if not f then return end
  f:write(text)
  f:close()
end

--! The installed game's Lua checksum (the last part of its build id, as
--! MultiplayerLobby.luaChecksum works it out) and the newest modification
--! time of its Lua files; nil where the engine cannot tell.
local function installedChecksum()
  local ok_lfs, lfs = pcall(require, "lfs")
  local ok_th, TH = pcall(require, "TH")
  if not ok_lfs or not ok_th or type(TH) ~= "table" or not TH.CRC32File then return nil end
  local files, newest = {}, 0
  local function walk(dir, rel)
    for name in lfs.dir(dir) do
      if name ~= "." and name ~= ".." then
        local path = dir .. name
        local mode = lfs.attributes(path, "mode")
        if mode == "directory" then
          walk(path .. pathsep, rel .. name .. "/")
        elseif name:match("%.lua$") then
          files[#files + 1] = {rel .. name, path}
          newest = math.max(newest, lfs.attributes(path, "modification") or 0)
        end
      end
    end
  end
  if not pcall(walk, code_dir, "") or #files == 0 then return nil end
  table.sort(files, function(a, b) return a[1] < b[1] end)
  local parts = {}
  for _, f in ipairs(files) do
    local fh = io.open(f[2], "rb")
    if fh then
      parts[#parts + 1] = f[1] .. "\0" .. fh:read("*a"):gsub("\r", "")
      fh:close()
    end
  end
  return string.format("%08x", TH.CRC32File(table.concat(parts, "\0"))), newest
end

local build = (read("current.txt") or ""):match("^(%x%x%x%x%x%x%x%x)%s*$")
if not build then return nil end
if read("starting.txt") then
  print("The downloaded build " .. build .. " did not start last time: starting the installed game.")
  os.remove(builds .. "current.txt")
  os.remove(builds .. "starting.txt")
  return nil
end
local installed, newest = installedChecksum()
if installed then
  local chosen_with = (read("installed.txt") or ""):match("^(%x%x%x%x%x%x%x%x)%s*$")
  local changed
  if installed == build then
    changed = true -- (the chosen build is the installed game itself)
  elseif chosen_with then
    changed = chosen_with ~= installed
  else
    -- Chosen by an older game, which did not write down what was installed:
    -- the installed game came later if its files are newer than that choice.
    local chosen_at = require("lfs").attributes(builds .. "current.txt", "modification") or 0
    changed = newest > chosen_at
    if not changed then write("installed.txt", installed .. "\n") end
  end
  if changed then
    print("Another game was installed since build " .. build .. " was chosen: starting the installed game.")
    os.remove(builds .. "current.txt")
    os.remove(builds .. "installed.txt")
    return nil
  end
end
local dir = builds .. build .. pathsep
local main = io.open(dir .. "CorsixTH.lua", "rb")
if not main then return nil end
main:close()
write("starting.txt", build .. "\n")
print("Starting the downloaded build " .. build .. " (" .. dir .. ")")
return dir .. "CorsixTH.lua", {
  "--pack-of=" .. base_dir,
  "--config-file=" .. config_file,
  "--hotkeys-file=" .. hotkeys_file,
}
