-- [nfnl] spec/fnl/lib/color_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local assert = require("luassert.assert")
local color = require("fugitive-treesitter.lib.color")
local tolerance = 0.0001
local function hex(s)
  return tonumber(s, 16)
end
local function _2_()
  local function _3_()
    local r, g, b = color["separate-channels"](hex("4a272f"))
    assert.equals(74, r)
    assert.equals(39, g)
    return assert.equals(47, b)
  end
  it("splits a color into its channels", _3_)
  local function _4_()
    for _, value in ipairs({hex("000000"), hex("ffffff"), hex("4a272f"), hex("243e4a")}) do
      local r, g, b = color["separate-channels"](value)
      assert.equals(value, color["join-channels"](r, g, b))
    end
    return nil
  end
  return it("round-trips through join-channels", _4_)
end
describe("separate-channels", _2_)
local function _5_()
  local function _6_()
    local red = color["rgb->hsl"](hex("ff0000"))
    local green = color["rgb->hsl"](hex("00ff00"))
    local blue = color["rgb->hsl"](hex("0000ff"))
    assert.near(0, red.h, tolerance)
    assert.near(120, green.h, tolerance)
    assert.near(240, blue.h, tolerance)
    assert.near(1, red.s, tolerance)
    return assert.near(0.5, red.l, tolerance)
  end
  it("reads the primaries", _6_)
  local function _7_()
    local white = color["rgb->hsl"](hex("ffffff"))
    local black = color["rgb->hsl"](hex("000000"))
    local grey = color["rgb->hsl"](hex("808080"))
    assert.near(0, white.s, tolerance)
    assert.near(1, white.l, tolerance)
    assert.near(0, black.s, tolerance)
    assert.near(0, black.l, tolerance)
    return assert.near(0, grey.s, tolerance)
  end
  it("gives a grey no saturation", _7_)
  local function _8_()
    local hsl = color["rgb->hsl"](hex("4a272f"))
    assert.near(346.29, hsl.h, 0.01)
    assert.near(0.3097, hsl.s, tolerance)
    return assert.near(0.2216, hsl.l, tolerance)
  end
  return it("reads a muted diff background", _8_)
end
describe("rgb->hsl", _5_)
local function _9_()
  local function _10_()
    for _, value in ipairs({hex("ff0000"), hex("ffff00"), hex("00ff00"), hex("00ffff"), hex("0000ff"), hex("ff00ff"), hex("ffffff"), hex("000000"), hex("4a272f"), hex("243e4a")}) do
      assert.equals(value, color["hsl->rgb"](color["rgb->hsl"](value)))
    end
    return nil
  end
  it("round-trips every hue sector", _10_)
  local function _11_()
    return assert.equals(color["hsl->rgb"]({h = 10, s = 0.5, l = 0.5}), color["hsl->rgb"]({h = 370, s = 0.5, l = 0.5}))
  end
  it("wraps a hue outside the circle", _11_)
  local function _12_()
    assert.equals(hex("ffffff"), color["hsl->rgb"]({h = 0, s = 1, l = 1}))
    return assert.equals(hex("000000"), color["hsl->rgb"]({h = 0, s = 1, l = 0}))
  end
  return it("clamps rather than overflowing", _12_)
end
return describe("hsl->rgb", _9_)
