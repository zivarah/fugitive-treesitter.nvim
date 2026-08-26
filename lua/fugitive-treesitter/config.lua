-- [nfnl] fnl/fugitive-treesitter/config.fnl
local defaults = {max_lines = 10000, derived_background = {saturation = 0.35, lightness = {dark = 0.18, light = 0.85}}, range_diff = {enabled = true, earlier_series_dim_factor = 0.4, commit_pair_mute_factor = 0.4}}
local options = vim.deepcopy(defaults)
local function unknown_keys(opts, known, _3fprefix)
  local unknown = {}
  for key, value in pairs(opts) do
    local path
    if _3fprefix then
      path = (_3fprefix .. key)
    else
      path = key
    end
    local _3fknown = known[key]
    if (nil == _3fknown) then
      table.insert(unknown, path)
    elseif (("table" == type(_3fknown)) and ("table" == type(value))) then
      for _, name in ipairs(unknown_keys(value, _3fknown, (path .. "."))) do
        table.insert(unknown, name)
      end
    else
    end
  end
  return unknown
end
local function validate_options(opts, known, _3fprefix)
  local prefix = (_3fprefix or "")
  for key, value in pairs(opts) do
    local case_3_ = known[key]
    if (nil ~= case_3_) then
      local expected = case_3_
      local path = (prefix .. key)
      vim.validate(path, value, type(expected))
      if ("table" == type(expected)) then
        validate_options(value, expected, (path .. "."))
      else
      end
    else
    end
  end
  return nil
end
local function setup(_3fopts)
  vim.validate("opts", _3fopts, "table", true)
  local opts = (_3fopts or {})
  local unknown = unknown_keys(opts, defaults)
  if (#unknown > 0) then
    vim.notify(("fugitive-treesitter: unknown options specified: " .. table.concat(unknown, ", ")), vim.log.levels.WARN)
  else
  end
  local merged = vim.tbl_deep_extend("force", defaults, (_3fopts or {}))
  validate_options(merged, defaults)
  options = merged
  return nil
end
local function get()
  return options
end
return {setup = setup, get = get}
