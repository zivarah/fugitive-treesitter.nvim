;;; Healthcheck for the plugin (`:checkhealth fugitive-treesitter`).

(local minimum-version :0.12)

(fn version-supported? []
  "Test whether the running Neovim is new enough for the plugin."
  (= 1 (vim.fn.has (.. :nvim- minimum-version))))

(fn check-neovim []
  "Report whether the running Neovim is new enough."
  (let [version (tostring (vim.version))]
    (if (version-supported?)
        (vim.health.ok (string.format "Neovim %s" version))
        (vim.health.error (string.format "Neovim %s is too old" version)
                          "The plugin needs Neovim 0.12 or newer for `vim.text.diff`."))))

(fn check-fugitive []
  "Report whether vim-fugitive is available."
  (if (= 2 (vim.fn.exists ":Git"))
      (vim.health.ok "vim-fugitive is loaded")
      ;; Detect if fugitive is on the runtime path in case it's lazy loaded.
      (> (length (vim.api.nvim_get_runtime_file :plugin/fugitive.vim false)) 0)
      (vim.health.ok "vim-fugitive is installed, and not loaded yet")
      (vim.health.error "vim-fugitive not found"
                        "Install https://github.com/tpope/vim-fugitive.")))

(fn check-parsers []
  "Report how many treesitter parsers are installed."
  (let [count (length (vim.api.nvim_get_runtime_file :parser/* true))]
    (if (> count 0)
        (vim.health.ok (string.format "%d treesitter parsers installed" count))
        (vim.health.warn "No treesitter parser is installed"
                         "A hunk is only syntax highlighted when a parser for its language is installed."))))

(fn report-options []
  "Report the options in effect."
  (let [config (require :fugitive-treesitter.config)
        opts (config.get)]
    (vim.health.info (.. "Configured options: " (vim.inspect opts)))))

(fn check-diff-colors []
  "Report whether the colorscheme gives the standard diff groups a background."
  (each [_ name (ipairs [:DiffAdd :DiffDelete])]
    (let [hl (vim.api.nvim_get_hl 0 {: name :link false})]
      (if hl.bg
          (vim.health.ok (string.format "%s has background #%06x" name hl.bg))
          (vim.health.info (string.format "%s has no background" name))))))

(fn describe-group [name]
  "Describe how one of the plugin's highlight groups resolved.

  Parameters:
    `name`  The name of the group.

  Returns the description."
  (let [raw (vim.api.nvim_get_hl 0 {: name})
        resolved (vim.api.nvim_get_hl 0 {: name :link false})]
    (if raw.link
        (string.format "%s links to %s" name raw.link)
        resolved.bg
        (string.format "%s background #%06x" name resolved.bg)
        (string.format "%s has no background" name))))

(fn report-highlights []
  "Report how each of the plugin's highlight groups resolved."
  (let [highlight (require :fugitive-treesitter.highlight)]
    (highlight.ensure)
    (each [_ name (ipairs [highlight.add-group highlight.delete-group])]
      (vim.health.info (describe-group name)))))

(fn check []
  "Report the state of the plugin. Neovim calls this function for
  `:checkhealth fugitive-treesitter`."
  (vim.health.start "fugitive-treesitter: requirements")
  (check-neovim)
  (check-fugitive)
  (check-parsers)
  (vim.health.start "fugitive-treesitter: options")
  (report-options)
  (vim.health.start "fugitive-treesitter: colors")
  (check-diff-colors)
  (report-highlights))

{: check : version-supported? : minimum-version}
