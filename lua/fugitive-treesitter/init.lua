-- [nfnl] fnl/fugitive-treesitter/init.fnl
local config = require("fugitive-treesitter.config")
local function setup(_3fopts)
  config.setup(_3fopts)
  return nil
end
return {setup = setup}
