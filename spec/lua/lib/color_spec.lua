-- [nfnl] spec/fnl/lib/color_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local assert = require("luassert.assert")
local color = require("fugitive-treesitter.lib.color")
local tolerance = 0.0001
local function _2_()
  local function _3_()
    local r, g, b = color["separate-channels"](4859695)
    assert.equals(74, r)
    assert.equals(39, g)
    return assert.equals(47, b)
  end
  it("splits a color into its channels", _3_)
  local function _4_()
    for _, value in ipairs({0, 16777215, 4859695, 2375242}) do
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
    local red = color["rgb->hsl"](16711680)
    local green = color["rgb->hsl"](65280)
    local blue = color["rgb->hsl"](255)
    assert.near(0, red.h, tolerance)
    assert.near(120, green.h, tolerance)
    assert.near(240, blue.h, tolerance)
    assert.near(1, red.s, tolerance)
    return assert.near(0.5, red.l, tolerance)
  end
  it("reads the primaries", _6_)
  local function _7_()
    local white = color["rgb->hsl"](16777215)
    local black = color["rgb->hsl"](0)
    local grey = color["rgb->hsl"](8421504)
    assert.near(0, white.s, tolerance)
    assert.near(1, white.l, tolerance)
    assert.near(0, black.s, tolerance)
    assert.near(0, black.l, tolerance)
    return assert.near(0, grey.s, tolerance)
  end
  it("gives a grey no saturation", _7_)
  local function _8_()
    local hsl = color["rgb->hsl"](4859695)
    assert.near(346.29, hsl.h, 0.01)
    assert.near(0.3097, hsl.s, tolerance)
    return assert.near(0.2216, hsl.l, tolerance)
  end
  return it("reads a muted diff background", _8_)
end
describe("rgb->hsl", _5_)
local function _9_()
  local function _10_()
    return assert.equals(4859695, color.blend(4859695, 0, 0))
  end
  it("keeps the color it starts from at 0", _10_)
  local function _11_()
    return assert.equals(0, color.blend(4859695, 0, 1))
  end
  it("reaches the color it moves to at 1", _11_)
  local function _12_()
    return assert.equals(8421504, color.blend(0, 16777215, 0.5))
  end
  it("meets in the middle at 0.5", _12_)
  local function _13_()
    return assert.equals(8388736, color.blend(16711680, 255, 0.5))
  end
  it("moves each channel on its own", _13_)
  local function _14_()
    return assert.equals(4859695, color.blend(4859695, 4859695, 0.5))
  end
  return it("changes nothing when the two colors match", _14_)
end
describe("blend", _9_)
local function _15_()
  local function _16_()
    for _, value in ipairs({16711680, 16776960, 65280, 65535, 255, 16711935, 16777215, 0, 4859695, 2375242}) do
      assert.equals(value, color["hsl->rgb"](color["rgb->hsl"](value)))
    end
    return nil
  end
  it("round-trips every hue sector", _16_)
  local function _17_()
    return assert.equals(color["hsl->rgb"]({h = 10, s = 0.5, l = 0.5}), color["hsl->rgb"]({h = 370, s = 0.5, l = 0.5}))
  end
  it("wraps a hue outside the circle", _17_)
  local function _18_()
    assert.equals(16777215, color["hsl->rgb"]({h = 0, s = 1, l = 1}))
    return assert.equals(0, color["hsl->rgb"]({h = 0, s = 1, l = 0}))
  end
  return it("clamps rather than overflowing", _18_)
end
return describe("hsl->rgb", _15_)
