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
    return vim.health.error(string.format("Neovim %s is too old", version), string.format("The plugin needs Neovim %s or newer.", minimum_version))
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
local function check_diff_colors()
  for _, name in ipairs({"DiffAdd", "DiffDelete"}) do
    local hl = vim.api.nvim_get_hl(0, {name = name, link = false})
    if hl.bg then
      vim.health.ok(string.format("%s has background #%06x", name, hl.bg))
    else
      vim.health.info(string.format("%s has no background", name))
    end
  end
  return nil
end
local function describe_group(name)
  local raw = vim.api.nvim_get_hl(0, {name = name})
  local resolved = vim.api.nvim_get_hl(0, {name = name, link = false})
  if raw.link then
    return string.format("%s links to %s", name, raw.link)
  elseif resolved.bg then
    return string.format("%s background #%06x", name, resolved.bg)
  else
    return string.format("%s has no background", name)
  end
end
local function report_highlights()
  local highlight = require("fugitive-treesitter.highlight")
  highlight.ensure()
  for _, name in ipairs({highlight["add-group"], highlight["delete-group"]}) do
    vim.health.info(describe_group(name))
  end
  return nil
end
local function check()
  vim.health.start("fugitive-treesitter: requirements")
  check_neovim()
  check_fugitive()
  check_parsers()
  vim.health.start("fugitive-treesitter: options")
  report_options()
  vim.health.start("fugitive-treesitter: colors")
  check_diff_colors()
  return report_highlights()
end
return {check = check, ["version-supported?"] = version_supported_3f, ["minimum-version"] = minimum_version}
