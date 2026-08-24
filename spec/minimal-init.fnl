;;; Runtime path for the headless Neovim that runs the specs.

(each [_ dep (ipairs (vim.fn.glob :./.deps/plugins/* true true))]
  (vim.opt.runtimepath:append dep))

(vim.opt.runtimepath:append ".")

;; Ensure that `:PlenaryBustedDirectory` is available.
(vim.cmd "runtime plugin/plenary.vim")
