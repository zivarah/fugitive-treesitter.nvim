(when (not vim.g.loaded_fugitive_treesitter)
  (set vim.g.loaded_fugitive_treesitter true)
  (let [{: version-supported? : minimum-version} (require :fugitive-treesitter.health)]
    (if (not (version-supported?))
        (vim.notify (.. "fugitive-treesitter.nvim needs Neovim "
                        minimum-version " or newer.")
                    vim.log.levels.WARN)
        (let [attach (require :fugitive-treesitter.attach)]
          (attach.enable)))))
