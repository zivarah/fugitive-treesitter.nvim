-- [nfnl] spec/minimal-init.fnl
for _, dep in ipairs(vim.fn.glob("./.deps/plugins/*", true, true)) do
  vim.opt.runtimepath:append(dep)
end
vim.opt.runtimepath:append(".")
return vim.cmd("runtime plugin/plenary.vim")
