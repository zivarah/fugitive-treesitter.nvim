;;; The highlight groups that the plugin puts on diff lines.

(local color (require :fugitive-treesitter.lib.color))
(local config (require :fugitive-treesitter.config))

(local add-group :FugitiveTreesitterAdd)
(local delete-group :FugitiveTreesitterDelete)

(var defined? false)

(fn resolved-hl [group]
  "Get the attributes of a highlight group, following any link.

  Parameters:
    `group`  The name of the group.

  Returns the attribute table. See |nvim_get_hl()|. The table has no `fg` or
  `bg` key if the group does not set one."
  (vim.api.nvim_get_hl 0 {:name group :link false}))

(fn accent-bg [accent-group]
  "Derive a diff background from the foreground of a semantic accent group.

  The derived color keeps the hue of the accent alone, and takes its saturation
  and its lightness from the `derived_background` option. Those default to a low
  saturation and a lightness close to the editor background, so that the color
  reads as a tint behind the code rather than a block of color.

  Parameters:
    `accent-group`  The name of the group to take the foreground from.

  Returns the 24-bit RGB integer, or nil if `accent-group` has no foreground."
  (let [hl (resolved-hl accent-group)
        opts (config.get)]
    (if hl.fg
        (color.recolor hl.fg opts.derived_background.saturation
                       (. opts.derived_background.lightness vim.o.background)))))

(fn define-line [name diff-group accent-group]
  "Define the line group of one diff side.

  A link to `diff-group` is preferred, so that the plugin shows the
  colorscheme's own diff color untouched. If that group has no background, then
  the backround color is derived from `accent-group`'s *foreground* instead.

  Parameters:
    `name`          The name of the group to define.
    `diff-group`    The name of the standard diff group to prefer.
    `accent-group`  The name of the semantic accent group to fall back to."
  (let [diff-hl (resolved-hl diff-group)]
    (if diff-hl.bg
        (vim.api.nvim_set_hl 0 name {:link diff-group})
        (case (accent-bg accent-group)
          bg (vim.api.nvim_set_hl 0 name {: bg})
          _ (vim.api.nvim_set_hl 0 name {:link diff-group})))))

(fn define []
  "Define every highlight group that the plugin uses."
  (define-line add-group :DiffAdd :Added)
  (define-line delete-group :DiffDelete :Removed)
  (set defined? true))

(fn ensure []
  "Define the highlight groups unless they are already defined.

  Callers run this before they place an extmark, rather than at startup, so
  that the groups come from the colorscheme that is actually loaded."
  (when (not defined?)
    (define)))

(fn invalidate []
  "Forget that the groups are defined, so that the next `ensure` defines them
  again.

  A colorscheme normally runs `:highlight clear`, which removes the groups, and
  the derived colors have to be worked out again from the new diff colors, so
  the `ColorScheme` autocmd calls this."
  (set defined? false))

{: add-group : delete-group : ensure : invalidate}
