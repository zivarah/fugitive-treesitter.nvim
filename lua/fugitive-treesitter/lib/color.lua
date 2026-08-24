-- [nfnl] fnl/fugitive-treesitter/lib/color.fnl
local function to_byte(v)
  return math.min(math.max(math.floor(((v * 255) + 0.5)), 0), 255)
end
local function separate_channels(rgb)
  local r = (math.floor((rgb / 65536)) % 256)
  local g = (math.floor((rgb / 256)) % 256)
  local b = (rgb % 256)
  return r, g, b
end
local function max_chroma(l)
  return (1 - math.abs(((2 * l) - 1)))
end
local function moving_offset(degrees, chroma)
  local ramp = ((degrees / 60) % 2)
  return (chroma * (1 - math.abs((ramp - 1))))
end
local function sector_channels(degrees, chroma, moving)
  assert(((0 <= degrees) and (degrees <= 360)), ("hue out of range: " .. degrees))
  if (degrees < 60) then
    return chroma, moving, 0
  elseif (degrees < 120) then
    return moving, chroma, 0
  elseif (degrees < 180) then
    return 0, chroma, moving
  elseif (degrees < 240) then
    return 0, moving, chroma
  elseif (degrees < 300) then
    return moving, 0, chroma
  else
    return chroma, 0, moving
  end
end
local function join_channels(r, g, b)
  return ((r * 65536) + (g * 256) + b)
end
local function hue(r, g, b)
  local brightest = math.max(r, g, b)
  local chroma = (brightest - math.min(r, g, b))
  local degrees
  if (0 == chroma) then
    degrees = 0
  elseif (brightest == r) then
    degrees = (60 * ((g - b) / chroma))
  elseif (brightest == g) then
    degrees = (120 + (60 * ((b - r) / chroma)))
  else
    degrees = (240 + (60 * ((r - g) / chroma)))
  end
  return (degrees % 360)
end
local function rgb__3ehsl(rgb)
  local r255, g255, b255 = separate_channels(rgb)
  local r = (r255 / 255)
  local g = (g255 / 255)
  local b = (b255 / 255)
  local brightest = math.max(r, g, b)
  local darkest = math.min(r, g, b)
  local chroma = (brightest - darkest)
  local lightness = ((brightest + darkest) / 2)
  local saturation
  if (0 == chroma) then
    saturation = 0
  else
    saturation = (chroma / max_chroma(lightness))
  end
  local hue0 = hue(r, g, b)
  return {h = hue0, s = saturation, l = lightness}
end
local function hsl__3ergb(_4_)
  local h = _4_.h
  local s = _4_.s
  local l = _4_.l
  local degrees = (h % 360)
  local chroma = (max_chroma(l) * s)
  local moving = moving_offset(degrees, chroma)
  local r, g, b = sector_channels(degrees, chroma, moving)
  local darkest = (l - (chroma / 2))
  local r_2a = to_byte((r + darkest))
  local g_2a = to_byte((g + darkest))
  local b_2a = to_byte((b + darkest))
  return join_channels(r_2a, g_2a, b_2a)
end
local function recolor(rgb, saturation, lightness)
  local hsl = rgb__3ehsl(rgb)
  local hsl_2a = {h = hsl.h, s = saturation, l = lightness}
  return hsl__3ergb(hsl_2a)
end
return {["separate-channels"] = separate_channels, ["join-channels"] = join_channels, ["rgb->hsl"] = rgb__3ehsl, ["hsl->rgb"] = hsl__3ergb, recolor = recolor}
