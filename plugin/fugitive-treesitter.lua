-- [nfnl] plugin/fugitive-treesitter.fnl
local minimum_version = "0.12"
local function version_supported_3f()
  return (1 == vim.fn.has(("nvim-" .. minimum_version)))
end
if not vim.g.loaded_fugitive_treesitter then
  vim.g.loaded_fugitive_treesitter = true
  if not version_supported_3f() then
    return vim.notify(("fugitive-treesitter.nvim needs Neovim " .. minimum_version .. " or newer."), vim.log.levels.WARN)
  else
    return nil
  end
else
  return nil
end
