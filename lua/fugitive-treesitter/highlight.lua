-- [nfnl] fnl/fugitive-treesitter/highlight.fnl
local color = require("fugitive-treesitter.lib.color")
local config = require("fugitive-treesitter.config")
local add_group = "FugitiveTreesitterAdd"
local delete_group = "FugitiveTreesitterDelete"
local add_dim_group = "FugitiveTreesitterAddDim"
local delete_dim_group = "FugitiveTreesitterDeleteDim"
local commit_group = "FugitiveTreesitterCommit"
local commit_add_group = "FugitiveTreesitterCommitAdd"
local commit_delete_group = "FugitiveTreesitterCommitDelete"
local hunk_group = "FugitiveTreesitterHunk"
local patch_hunk_group = "FugitiveTreesitterPatchHunk"
local file_group = "FugitiveTreesitterFile"
local commit_add_sources = {"Added", "diffAdded"}
local commit_delete_sources = {"Removed", "diffRemoved"}
local hunk_sources = {"diffLine", "diffSubname", "Title"}
local file_sources = {"diffFile", "Directory"}
local defined_3f = false
local function resolved_hl(group)
  return vim.api.nvim_get_hl(0, {name = group, link = false})
end
local function accent_bg(accent_group)
  local hl = resolved_hl(accent_group)
  if hl.fg then
    local opts = config.get()
    local saturation = opts.derived_background.saturation
    local lightness = opts.derived_background.lightness[vim.o.background]
    return color.recolor(hl.fg, saturation, lightness)
  else
    return nil
  end
end
local function normal_bg()
  local hl = resolved_hl("Normal")
  if hl.bg then
    return hl.bg
  elseif ("dark" == vim.o.background) then
    return 0
  else
    return 16777215
  end
end
local function define_line(side)
  local diff_hl = resolved_hl(side["diff-group"])
  local _3fbg = (diff_hl.bg or accent_bg(side["accent-group"]))
  local opts = config.get()
  local dim_factor = opts.range_diff.earlier_series_dim_factor
  local hl_opts
  if diff_hl.bg then
    hl_opts = {link = side["diff-group"]}
  elseif _3fbg then
    hl_opts = {bg = _3fbg}
  else
    hl_opts = {link = side["diff-group"]}
  end
  local dim_hl_opts
  if _3fbg then
    dim_hl_opts = {bg = color.blend(_3fbg, normal_bg(), dim_factor)}
  else
    dim_hl_opts = {link = side.name}
  end
  vim.api.nvim_set_hl(0, side.name, hl_opts)
  return vim.api.nvim_set_hl(0, side["dim-name"], dim_hl_opts)
end
local function first_with_fg(groups)
  local _3ffound = nil
  for _, group_name in ipairs(groups) do
    if _3ffound then break end
    local hl = resolved_hl(group_name)
    if hl.fg then
      _3ffound = group_name
    else
      _3ffound = nil
    end
  end
  return _3ffound
end
local function define_text(name, sources)
  return vim.api.nvim_set_hl(0, name, {link = (first_with_fg(sources) or sources[1])})
end
local function define_reversed(name, sources)
  local case_6_ = first_with_fg(sources)
  if (nil ~= case_6_) then
    local group = case_6_
    local hl = resolved_hl(group)
    hl.reverse = not hl.reverse
    return vim.api.nvim_set_hl(0, name, hl)
  else
    local _ = case_6_
    return vim.api.nvim_set_hl(0, name, {link = sources[1]})
  end
end
local function define_muted(name)
  local hl = resolved_hl("Normal")
  local opts = config.get()
  local mute_factor = opts.range_diff.commit_pair_mute_factor
  if hl.fg then
    hl.fg = color.blend(hl.fg, normal_bg(), mute_factor)
    return vim.api.nvim_set_hl(0, name, hl)
  else
    return vim.api.nvim_set_hl(0, name, {link = "Comment"})
  end
end
local function define()
  define_line({name = add_group, ["dim-name"] = add_dim_group, ["diff-group"] = "DiffAdd", ["accent-group"] = "Added"})
  define_line({name = delete_group, ["dim-name"] = delete_dim_group, ["diff-group"] = "DiffDelete", ["accent-group"] = "Removed"})
  define_muted(commit_group)
  define_text(commit_add_group, commit_add_sources)
  define_text(commit_delete_group, commit_delete_sources)
  define_text(patch_hunk_group, hunk_sources)
  define_text(file_group, file_sources)
  define_reversed(hunk_group, hunk_sources)
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
return {["add-group"] = add_group, ["delete-group"] = delete_group, ["add-dim-group"] = add_dim_group, ["delete-dim-group"] = delete_dim_group, ["commit-group"] = commit_group, ["commit-add-group"] = commit_add_group, ["commit-delete-group"] = commit_delete_group, ["hunk-group"] = hunk_group, ["patch-hunk-group"] = patch_hunk_group, ["file-group"] = file_group, ensure = ensure, invalidate = invalidate}
