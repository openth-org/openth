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

require("corsixth")
require("class_test_base")
require("mp_session")
require("mp_lobby")

-- A speed vote for a slower game shows << on its icon, not >> (Jan,
-- 2026-11-21): the vote's direction, and the mirrored picture.
describe("Speed vote icon", function()
  it("knows a vote for a slower game", function()
    local world = {mp_speed = "Normal"}
    assert.is_true(MultiplayerSession.voteIsSlower(world, "Slowest"))
    assert.is_true(MultiplayerSession.voteIsSlower(world, "Slower"))
    assert.is_false(MultiplayerSession.voteIsSlower(world, "Max speed"))
    assert.is_false(MultiplayerSession.voteIsSlower(world, "Normal"))
    -- Paused: compared with the speed the game goes on at.
    world = {mp_speed = "Pause", mp_resume_speed = "Max speed"}
    assert.is_true(MultiplayerSession.voteIsSlower(world, "Normal"))
    assert.is_false(MultiplayerSession.voteIsSlower({mp_speed = "Pause"}, "Max speed"))
  end)

  it("mirrors only the picture inside the button", function()
    local icon = {w = 30, h = 28, colours = {1, 2, 3},
      runs = {1, 9, 5, 2, -- inside: columns 9-10 become 19-20
              1, 12, 6, 1, -- inside: column 12 becomes 17
              1, 3, 5, 4, -- the frame: unchanged
              1, 7, 20, 15}} -- across the frame: unchanged
    local m = MultiplayerSession.mirrorIcon(icon, 9, 20)
    assert.same({1, 19, 5, 2, 1, 17, 6, 1, 1, 3, 5, 4, 1, 7, 20, 15}, m.runs)
    assert.equal(icon.colours, m.colours)
    assert.same({1, 9, 5, 2, 1, 12, 6, 1, 1, 3, 5, 4, 1, 7, 20, 15}, icon.runs) -- (the original stays)
  end)
end)
