;;; Compile every Fennel source in the project to Lua with nfnl.

(local {: compile-all-files} (require :nfnl.api))

(local config-file :.nfnl.fnl)

(vim.fn.mkdir (vim.fn.stdpath :state) :p)
(vim.secure.trust {:action :allow :path config-file})

(local broken (icollect [_ result (ipairs (compile-all-files))]
                (if (= :compilation-error result.status) result)))

(when (> (length broken) 0)
  (io.stderr:write "nfnl could not compile every file:\n")
  (each [_ {:error message} (ipairs broken)]
    (io.stderr:write (.. (vim.trim message) "\n")))
  (os.exit 1))
