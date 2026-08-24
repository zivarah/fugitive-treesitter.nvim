-- [nfnl] script/compile.fnl
local _local_1_ = require("nfnl.api")
local compile_all_files = _local_1_["compile-all-files"]
local config_file = ".nfnl.fnl"
vim.fn.mkdir(vim.fn.stdpath("state"), "p")
vim.secure.trust({action = "allow", path = config_file})
local broken
do
  local tbl_26_ = {}
  local i_27_ = 0
  for _, result in ipairs(compile_all_files()) do
    local val_28_
    if ("compilation-error" == result.status) then
      val_28_ = result
    else
      val_28_ = nil
    end
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  broken = tbl_26_
end
if (#broken > 0) then
  io.stderr:write("nfnl could not compile every file:\n")
  for _, _4_ in ipairs(broken) do
    local message = _4_.error
    io.stderr:write((vim.trim(message) .. "\n"))
  end
  return os.exit(1)
else
  return nil
end
