-- [nfnl] fnl/fugitive-treesitter/highlight.fnl
local color = require("fugitive-treesitter.lib.color")
local add_group = "FugitiveTreesitterAdd"
local delete_group = "FugitiveTreesitterDelete"
local base_lightness = {dark = 0.18, light = 0.85}
local base_saturation = 0.35
local defined_3f = false
local function resolved_hl(group)
  return vim.api.nvim_get_hl(0, {name = group, link = false})
end
local function accent_bg(accent_group)
  local hl = resolved_hl(accent_group)
  if hl.fg then
    return color.recolor(hl.fg, base_saturation, base_lightness[vim.o.background])
  else
    return nil
  end
end
local function define_line(name, diff_group, accent_group)
  local diff_hl = resolved_hl(diff_group)
  if diff_hl.bg then
    return vim.api.nvim_set_hl(0, name, {link = diff_group})
  else
    local case_2_ = accent_bg(accent_group)
    if (nil ~= case_2_) then
      local bg = case_2_
      return vim.api.nvim_set_hl(0, name, {bg = bg})
    else
      local _ = case_2_
      return vim.api.nvim_set_hl(0, name, {link = diff_group})
    end
  end
end
local function define()
  define_line(add_group, "DiffAdd", "Added")
  define_line(delete_group, "DiffDelete", "Removed")
  defined_3f = true
  return nil
end
local function ensure()
  if not defined_3f then
    return define()
  else
    return nil
  end
end
local function invalidate()
  defined_3f = false
  return nil
end
return {["add-group"] = add_group, ["delete-group"] = delete_group, ensure = ensure, invalidate = invalidate}
