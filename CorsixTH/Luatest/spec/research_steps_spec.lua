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

require("corsixth")
require("class_test_base")
if not Window then class "Window" end
require("dialogs.fullscreen.research_policy")

-- The points a click on a research arrow moves: CorsixTH's own steps, but a
-- plain click 5 in multiplayer (Argus, 2026-11-24).
describe("Research arrows", function()
  local function steps(multiplayer)
    local out = {}
    for _, mods in ipairs({{}, {shift = true}, {ctrl = true}, {ctrl = true, shift = true}}) do
      out[#out + 1] = UIResearch.stepPoints(mods, multiplayer)
    end
    return out
  end

  it("move 1, 5, 20 and 100 points in single player", function()
    assert.same({1, 5, 20, 100}, steps(false))
  end)

  it("move 5 with a plain click in multiplayer, the rest as in single player", function()
    assert.same({5, 5, 20, 100}, steps(true))
  end)
end)
