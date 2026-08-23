-- [nfnl] fnl/fugitive-treesitter/config.fnl
local defaults = {}
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
local function setup(_3fopts)
  vim.validate("opts", _3fopts, "table", true)
  local opts = (_3fopts or {})
  local unknown = unknown_keys(opts, defaults)
  if (#unknown > 0) then
    vim.notify(("fugitive-treesitter: unknown options specified: " .. table.concat(unknown, ", ")), vim.log.levels.WARN)
  else
  end
  options = vim.tbl_deep_extend("force", defaults, opts)
  return nil
end
local function get()
  return options
end
return {setup = setup, get = get}
