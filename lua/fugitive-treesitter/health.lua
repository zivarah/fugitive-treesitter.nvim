-- [nfnl] fnl/fugitive-treesitter/health.fnl
local minimum_version = "0.12"
local function version_supported_3f()
  return (1 == vim.fn.has(("nvim-" .. minimum_version)))
end
local function check_neovim()
  local version = tostring(vim.version())
  if version_supported_3f() then
    return vim.health.ok(string.format("Neovim %s", version))
  else
    return vim.health.error(string.format("Neovim %s is too old", version), "The plugin needs Neovim 0.12 or newer for `vim.text.diff`.")
  end
end
local function check_fugitive()
  if (2 == vim.fn.exists(":Git")) then
    return vim.health.ok("vim-fugitive is loaded")
  elseif (#vim.api.nvim_get_runtime_file("plugin/fugitive.vim", false) > 0) then
    return vim.health.ok("vim-fugitive is installed, and not loaded yet")
  else
    return vim.health.error("vim-fugitive not found", "Install https://github.com/tpope/vim-fugitive.")
  end
end
local function check_parsers()
  local count = #vim.api.nvim_get_runtime_file("parser/*", true)
  if (count > 0) then
    return vim.health.ok(string.format("%d treesitter parsers installed", count))
  else
    return vim.health.warn("No treesitter parser is installed", "A hunk is only syntax highlighted when a parser for its language is installed.")
  end
end
local function report_options()
  local config = require("fugitive-treesitter.config")
  local opts = config.get()
  return vim.health.info(("Configured options: " .. vim.inspect(opts)))
end
local function check()
  vim.health.start("fugitive-treesitter: requirements")
  check_neovim()
  check_fugitive()
  check_parsers()
  vim.health.start("fugitive-treesitter: options")
  return report_options()
end
return {check = check, ["version-supported?"] = version_supported_3f, ["minimum-version"] = minimum_version}
