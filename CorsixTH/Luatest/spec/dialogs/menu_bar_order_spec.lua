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

-- Argus (2026-11-24): the Multiplayer menu comes before Debug on the menu
-- bar. UIMenuBar:addMenu takes the titles to put a menu in front of.
describe("Menu bar order", function()
  setup(function()
    require("corsixth")
    require("class_test_base")
    require("TH")
    require("utility")
    require("window")
    require("dialogs.menu")
  end)

  local saved_app
  before_each(function()
    saved_app = _G.TheApp
    _G.TheApp = {gfx = {getUIScale = function() return 1 end}}
  end)
  after_each(function()
    _G.TheApp = saved_app
  end)

  local function bar(titles)
    local self = {menus = {}, white_font = {sizeOf = function(_, s) return #s * 8 end}}
    for _, title in ipairs(titles) do
      UIMenuBar.addMenu(self, title, {items = {}})
    end
    return self
  end

  local function check(self, expected)
    local x = 0
    for i, title in ipairs(expected) do
      assert.equal(title, self.menus[i].title)
      assert.equal(x, self.menus[i].x, title)
      assert.equal(#title * 8 + 32, self.menus[i].width, title)
      x = x + self.menus[i].width
    end
    assert.equal(#expected, #self.menus)
  end

  it("adds at the end without a 'before' list", function()
    local self = bar({"FILE", "OPTIONS", "DEBUG"})
    UIMenuBar.addMenu(self, "MULTIPLAYER", {items = {}})
    check(self, {"FILE", "OPTIONS", "DEBUG", "MULTIPLAYER"})
  end)

  it("goes before the first menu named in the list", function()
    local self = bar({"FILE", "OPTIONS", "CHARTS", "DEBUG", "CHEATS"})
    UIMenuBar.addMenu(self, "MULTIPLAYER", {items = {}}, {"DEBUG", "CHEATS"})
    check(self, {"FILE", "OPTIONS", "CHARTS", "MULTIPLAYER", "DEBUG", "CHEATS"})
  end)

  it("goes before Cheats when there is no Debug menu", function()
    local self = bar({"FILE", "CHARTS", "CHEATS"})
    UIMenuBar.addMenu(self, "MULTIPLAYER", {items = {}}, {"DEBUG", "CHEATS"})
    check(self, {"FILE", "CHARTS", "MULTIPLAYER", "CHEATS"})
  end)

  it("goes at the end when none of them is there", function()
    local self = bar({"FILE", "CHARTS"})
    UIMenuBar.addMenu(self, "MULTIPLAYER", {items = {}}, {"DEBUG", "CHEATS"})
    check(self, {"FILE", "CHARTS", "MULTIPLAYER"})
  end)
end)
