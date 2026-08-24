;;; Public interface of the plugin.

(local attach (require :fugitive-treesitter.attach))
(local config (require :fugitive-treesitter.config))

(fn setup [?opts]
  "Set up the plugin.

  Calling this function is optional: the plugin highlights fugitive diffs with
  no configuration.

  Re-highlights any already-highlighted buffers, so the new options take effect
  immediately.

  Parameters:
    `?opts`  The user options. See |fugitive-treesitter-config|."
  (config.setup ?opts)
  (attach.redraw)
  nil)

(fn refresh [?buf]
  "Apply the diff highlights of a buffer again.

  The plugin normally does this by itself. If you find you need to call this
  yourself under normal use, please file a bug report.

  Parameters:
    `?buf`  The buffer number. Defaults to the current buffer."
  (attach.refresh ?buf))

(fn enable []
  "Start highlighting fugitive diffs.

  The plugin does this on startup, so this is only needed after `disable`."
  (attach.enable))

(fn disable []
  "Stop highlighting fugitive diffs, and remove the highlights that are already
  on screen."
  (attach.disable))

{: setup : refresh : enable : disable}
