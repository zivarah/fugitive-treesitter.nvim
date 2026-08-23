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

(fn check []
  "Report the state of the plugin. Neovim calls this function for
  `:checkhealth fugitive-treesitter`."
  (vim.health.start "fugitive-treesitter: requirements")
  (check-neovim)
  (check-fugitive)
  (check-parsers)
  (vim.health.start "fugitive-treesitter: options")
  (report-options))

{: check : version-supported? : minimum-version}
