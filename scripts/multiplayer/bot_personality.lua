--[[ Copyright (c) 2026 Jan Bakalar

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

--[[ The bots' characters. Each of the server's bot names (BOT_NAMES in
mp_server/corsixth_mp/server.py: Bot Agnes to Bot Hector) plays and talks in a
way of its own (Jan, 2026-11-28: "right now it does feel like the bots have
their own personalities and I would like to keep it that way"; the bots of a
room now share one game, bot_host.lua, and each keeps its own mind).

A character changes how a bot plays, not how strong it is: the level (easy,
normal, hard) stays the room's choice. A bot standing in for a person who
left has none (it plays their hospital quietly), nor has a bot with another
name (a saved hospital's player).

What a character may set (anything left out is as for every other bot):
  voice       a few words for the logs; the server's language model has its
              own copy (PERSONAS in mp_server/corsixth_mp/advisor.py)
  pace        days between its building steps, times this (Manager:paced)
  typing      its typing time before a chat line, times this
  reserve     the least it keeps in the bank when it builds or buys ($3,000
              for the others; only more counts)
  borrow      the project score from which it borrows for a project it
              cannot pay (20)
  scores      project -> score added to it ("room:research", "buy:bench",
              "hire:Researcher": Manager:projects' keys without the place)
  research    true: a bigger research room early, with four desks
              (Bot.research_heavy)
  share_days  game days between its research gifts to one ally (21)
  lend_days   game days between specialists lent to one ally (20)
  gift        {keep =, max =}: the bank it keeps and the most it sends at
              once to an ally who asks for money ($15,000 and $20,000)
  tricks      {first =, every =}: the time to its first dirty trick and
              between tricks, times these
  pays        what it pays a rival for research or a specialist, times this
  asks        what it asks a rival for a specialist, times this
  kind        true: its stock answers to rivals are friendly ones too

Its own lines are bot_chat.persona.<key> in the language files: greet (said
once, instead of the common greetings), remark (now and then, small talk
players can hide) and replies (its stock answers by kind). So a bot keeps its
character without the server's language model (Jan, 2026-11-28: the bots
should not depend on it; with it, the model answers in the same character). ]]

local M = {}

M.characters = {
  agnes = {
    voice = "kind and a bit slow",
    pace = 1.35, typing = 1.4,
    gift = {keep = 10000, max = 25000},
    tricks = {first = 1.8, every = 2.0},
    asks = 0.75,
    lend_days = 14,
    kind = true,
  },
  bertie = {
    voice = "sassy",
    typing = 0.8,
    gift = {keep = 20000, max = 15000},
    tricks = {first = 0.6, every = 0.65},
    pays = 0.75, asks = 1.5,
  },
  clive = {
    voice = "loves research",
    research = true,
    scores = {["hire:Researcher"] = 6},
    share_days = 10,
  },
  dora = {
    voice = "thrifty",
    reserve = 9000, borrow = 35,
    gift = {keep = 25000, max = 10000},
    tricks = {first = 1.3, every = 1.4},
    pays = 0.8, asks = 1.25,
    -- (A drinks machine pays for itself; a plant does not.)
    scores = {["buy:plant"] = -2, ["buy:bench"] = -1, ["buy:land"] = -3, ["buy:drinks_machine"] = 2},
  },
  edna = {
    voice = "homely",
    gift = {keep = 12000, max = 20000},
    tricks = {first = 1.4, every = 1.6},
    scores = {["buy:bench"] = 3, ["buy:plant"] = 3, ["buy:radiator"] = 3, ["buy:drinks_machine"] = 2,
        ["room:staff_room"] = 6, ["room:toilets"] = 4},
  },
  fergus = {
    voice = "bold",
    typing = 0.9,
    borrow = 12,
    tricks = {first = 0.85, every = 0.85},
    pays = 1.25,
    scores = {["buy:land"] = 8, ["room:operating_theatre"] = 3, ["room:scanner"] = 3},
  },
  gwen = {
    voice = "team player",
    typing = 0.8,
    gift = {keep = 10000, max = 25000},
    tricks = {first = 1.3, every = 1.5},
    share_days = 14, lend_days = 7,
  },
  hector = {
    voice = "grumpy veteran",
    pace = 0.9, typing = 1.2,
    gift = {keep = 20000, max = 15000},
    pays = 0.9,
    scores = {["room:gp"] = 4, ["buy:plant"] = -2, ["buy:bench"] = -1, ["buy:drinks_machine"] = -1},
  },
}

--! The character of a bot of this name ("Bot Agnes"), or nil: none for a
--! stand-in or another name. MP_BOT_PERSONA: "off" (tests: none for any
--! bot), or "<name>=<key>;..." to give a bot another one.
--!param name (string) the bot's name
--!param standin (boolean) it stands in for a person who left
--!param spec (string|nil) MP_BOT_PERSONA
--!return (table|nil) the character, with its key
function M.of(name, standin, spec)
  if standin or spec == "off" then return nil end
  local key = tostring(name):match("^Bot (%a+)$")
  for who, k in tostring(spec or ""):gmatch("([^;=]+)=([^;]+)") do
    if who:lower() == tostring(name):lower() then key = k end
  end
  key = key and key:lower()
  local c = key and M.characters[key]
  if not c then return nil end
  local out = {key = key}
  for k, v in pairs(c) do out[k] = v end
  out.scores = out.scores or {}
  return out
end

return M
