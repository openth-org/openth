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

-- The Progress Report's tooltips for another player's hospital
-- (multiplayer_window.goal_other) take the hospital's name, "goal:" or
-- "limit:", the goal's value and the current value, and show the goal first
-- as the tooltips for one's own hospital do (Argus, 2026-11-22). Every
-- language must take its values in that order: one left on the old order
-- would show the numbers in the wrong places.

local CRITERIA = {"reputation", "balance", "percentage_cured", "num_cured", "percentage_killed", "value"}
local LANGUAGES = {"brazilian_portuguese", "czech", "danish", "dutch", "english", "finnish", "french", "german",
  "greek", "hungarian", "iberic_portuguese", "italian", "japanese", "korean", "norwegian", "polish", "russian",
  "simplified_chinese", "spanish", "swedish", "traditional_chinese", "ukrainian"}

--! The goal_other strings of a language file: criterion -> format string.
local function goalOther(language)
  local f = assert(io.open("../Lua/languages/" .. language .. ".lua", "rb"))
  local text = f:read("*a")
  f:close()
  local out = {}
  for _, crit in ipairs(CRITERIA) do
    out[crit] = text:match("multiplayer_window%.goal_other%." .. crit .. ' = "([^"\n]*)"')
    if not out[crit] and language == "english" then
      local block = assert(text:match("goal_other = (%b{})"))
      out[crit] = block:match("\n%s*" .. crit .. ' = "([^"\n]*)"')
    end
  end
  return out
end

describe("Rival goal tooltips", function()
  for _, language in ipairs(LANGUAGES) do
    it("show the goal before the current value in " .. language, function()
      local strings = goalOther(language)
      for _, crit in ipairs(CRITERIA) do
        local s = strings[crit]
        assert.is_string(s, crit)
        local ok, text = pcall(string.format, s, "Name", "goal:", 450, 470)
        assert.is_true(ok, crit .. ": " .. tostring(text))
        local goal, current = text:find("450", 1, true), text:find("470", 1, true)
        assert.is_truthy(goal and current and goal < current, crit .. ": " .. text)
        assert.is_truthy(text:find("Name", 1, true) == 1, crit .. ": " .. text)
      end
    end)
  end
end)
