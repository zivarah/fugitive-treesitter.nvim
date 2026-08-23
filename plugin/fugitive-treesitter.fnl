(local minimum-version :0.12)

(fn version-supported? []
  "Test whether the running Neovim is new enough for the plugin."
  (= 1 (vim.fn.has (.. :nvim- minimum-version))))

(when (not vim.g.loaded_fugitive_treesitter)
  (set vim.g.loaded_fugitive_treesitter true)
  (when (not (version-supported?))
    (vim.notify (.. "fugitive-treesitter.nvim needs Neovim " minimum-version
                    " or newer.") vim.log.levels.WARN)))
