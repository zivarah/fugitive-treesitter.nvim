;;; Selecting the syntax that defines range-diff folds.

(local config (require :fugitive-treesitter.config))
(local scan (require :fugitive-treesitter.scan))

(local syntax-name :rangediff)
(local active-key :fugitive_treesitter_range_diff_folds)
(local previous-syntax-key :fugitive_treesitter_previous_syntax)

(fn current-syntax [buf]
  "Get the syntax of a buffer.

  Parameters:
    `buf`  The buffer number.

  Returns the syntax name, or an empty string if the buffer has no syntax."
  (vim.api.nvim_get_option_value :syntax {: buf}))

(fn define [buf]
  "Select the range-diff syntax for a buffer.

  Does nothing when the plugin already selected the syntax.

  Parameters:
    `buf`  The buffer number."
  (when (not (. vim.b buf active-key))
    (let [previous (current-syntax buf)]
      (vim.api.nvim_set_option_value :syntax syntax-name {: buf})
      (set (. vim.b buf previous-syntax-key) previous)
      (set (. vim.b buf active-key) true))))

(fn clear [buf]
  "Restore the syntax that a buffer had before the plugin defined its folds.

  Does not replace a syntax that another source selected after the plugin.

  Parameters:
    `buf`  The buffer number."
  (when (. vim.b buf active-key)
    (let [previous (or (. vim.b buf previous-syntax-key) "")]
      (set (. vim.b buf active-key) nil)
      (set (. vim.b buf previous-syntax-key) nil)
      (when (= syntax-name (current-syntax buf))
        (vim.api.nvim_set_option_value :syntax previous {: buf})))))

(fn update [buf]
  "Define or remove the range-diff syntax folds of a buffer.

  Defines the folds when the buffer contains range-diff output and both
  `range_diff.enabled` and `range_diff.define_folds` are true. Removes folds
  that this plugin defined in every other case.

  Parameters:
    `buf`  The buffer number."
  (let [opts (config.get)
        filetype (vim.api.nvim_get_option_value :filetype {: buf})
        define? (and (= :git filetype) opts.range_diff.enabled
                     opts.range_diff.define_folds
                     (scan.range-diff? (vim.api.nvim_buf_get_lines buf 0 -1
                                                                   false)))]
    (if define?
        (define buf)
        (clear buf))))

{: clear : update}
