-- [nfnl] fnl/fugitive-treesitter/fold.fnl
local config = require("fugitive-treesitter.config")
local scan = require("fugitive-treesitter.scan")
local syntax_name = "rangediff"
local active_key = "fugitive_treesitter_range_diff_folds"
local previous_syntax_key = "fugitive_treesitter_previous_syntax"
local function current_syntax(buf)
  return vim.api.nvim_get_option_value("syntax", {buf = buf})
end
local function define(buf)
  if not vim.b[buf][active_key] then
    local previous = current_syntax(buf)
    vim.api.nvim_set_option_value("syntax", syntax_name, {buf = buf})
    vim.b[buf][previous_syntax_key] = previous
    vim.b[buf][active_key] = true
    return nil
  else
    return nil
  end
end
local function clear(buf)
  if vim.b[buf][active_key] then
    local previous = (vim.b[buf][previous_syntax_key] or "")
    vim.b[buf][active_key] = nil
    vim.b[buf][previous_syntax_key] = nil
    if (syntax_name == current_syntax(buf)) then
      return vim.api.nvim_set_option_value("syntax", previous, {buf = buf})
    else
      return nil
    end
  else
    return nil
  end
end
local function update(buf)
  local opts = config.get()
  local filetype = vim.api.nvim_get_option_value("filetype", {buf = buf})
  local define_3f = (("git" == filetype) and opts.range_diff.enabled and opts.range_diff.define_folds and scan["range-diff?"](vim.api.nvim_buf_get_lines(buf, 0, -1, false)))
  if define_3f then
    return define(buf)
  else
    return clear(buf)
  end
end
return {clear = clear, update = update}
