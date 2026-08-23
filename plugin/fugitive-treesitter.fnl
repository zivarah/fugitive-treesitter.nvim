(fn on-colorscheme []
  "Drop the highlight groups so that the next diff buffer defines them again."
  (let [highlight (require :fugitive-treesitter.highlight)]
    (highlight.invalidate)))

(when (not vim.g.loaded_fugitive_treesitter)
  (set vim.g.loaded_fugitive_treesitter true)
  (let [{: version-supported? : minimum-version} (require :fugitive-treesitter.health)]
    (if (not (version-supported?))
        (vim.notify (.. "fugitive-treesitter.nvim needs Neovim "
                        minimum-version " or newer.")
                    vim.log.levels.WARN)
        (let [group (vim.api.nvim_create_augroup :fugitive-treesitter
                                                 {:clear true})]
          (vim.api.nvim_create_autocmd :ColorScheme
                                       {: group :callback on-colorscheme})))))
