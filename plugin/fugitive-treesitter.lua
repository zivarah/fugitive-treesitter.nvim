-- [nfnl] plugin/fugitive-treesitter.fnl
local function on_colorscheme()
  local highlight = require("fugitive-treesitter.highlight")
  return highlight.invalidate()
end
if not vim.g.loaded_fugitive_treesitter then
  vim.g.loaded_fugitive_treesitter = true
  local _let_1_ = require("fugitive-treesitter.health")
  local version_supported_3f = _let_1_["version-supported?"]
  local minimum_version = _let_1_["minimum-version"]
  if not version_supported_3f() then
    return vim.notify(("fugitive-treesitter.nvim needs Neovim " .. minimum_version .. " or newer."), vim.log.levels.WARN)
  else
    local group = vim.api.nvim_create_augroup("fugitive-treesitter", {clear = true})
    return vim.api.nvim_create_autocmd("ColorScheme", {group = group, callback = on_colorscheme})
  end
else
  return nil
end
