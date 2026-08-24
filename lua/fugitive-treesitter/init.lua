-- [nfnl] fnl/fugitive-treesitter/init.fnl
local attach = require("fugitive-treesitter.attach")
local config = require("fugitive-treesitter.config")
local function setup(_3fopts)
  config.setup(_3fopts)
  return nil
end
local function refresh(_3fbuf)
  return attach.refresh(_3fbuf)
end
local function enable()
  return attach.enable()
end
local function disable()
  return attach.disable()
end
return {setup = setup, refresh = refresh, enable = enable, disable = disable}
