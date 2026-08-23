;;; Public interface of the plugin.

(local config (require :fugitive-treesitter.config))

(fn setup [?opts]
  "Set up the plugin.

  Calling this function is optional. The plugin highlights fugitive diffs with
  no configuration at all, so call it only to change an option.

  Parameters:
    `?opts`  The user options. See |fugitive-treesitter-config|."
  (config.setup ?opts)
  nil)

{: setup}
