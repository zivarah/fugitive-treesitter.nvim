;;; The highlight groups that the plugin puts on diff lines.

(local color (require :fugitive-treesitter.lib.color))
(local config (require :fugitive-treesitter.config))

(local add-group :FugitiveTreesitterAdd)
(local delete-group :FugitiveTreesitterDelete)
(local add-dim-group :FugitiveTreesitterAddDim)
(local delete-dim-group :FugitiveTreesitterDeleteDim)
(local commit-group :FugitiveTreesitterCommit)
(local commit-add-group :FugitiveTreesitterCommitAdd)
(local commit-delete-group :FugitiveTreesitterCommitDelete)
(local hunk-group :FugitiveTreesitterHunk)
(local patch-hunk-group :FugitiveTreesitterPatchHunk)
(local file-group :FugitiveTreesitterFile)

;; Where each text color comes from, in order of preference. A colorscheme
;; defines the `diff` groups only as far as it cares to, and leaves the rest
;; empty, so each list ends in a group that a colorscheme is likely to set.
(local commit-add-sources [:Added :diffAdded])
(local commit-delete-sources [:Removed :diffRemoved])
(local hunk-sources [:diffLine :diffSubname :Title])
(local file-sources [:diffFile :Directory])

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
  (let [hl (resolved-hl accent-group)]
    (if hl.fg
        (let [opts (config.get)
              saturation opts.derived_background.saturation
              lightness (. opts.derived_background.lightness vim.o.background)]
          (color.recolor hl.fg saturation lightness)))))

(fn normal-bg []
  "Find the background color of the editor.

  If `Normal` has no background defined, defaults to black or white depending on
  the value of vim.o.background.

  Returns the 24-bit RGB integer."
  (let [hl (resolved-hl :Normal)]
    (if hl.bg hl.bg
        (= :dark vim.o.background) 0x000000
        0xffffff)))

(fn define-line [side]
  "Define the line groups of one diff side.

  A link to `diff-group` is preferred for the plain group, so that the plugin
  shows the colorscheme's own diff color untouched. If that group has no
  background, then the background color is derived from `accent-group`'s
  *foreground* instead.

  The dim group always sets a color of its own, because it has to move the
  background of the side toward the background of the editor, by the
  `range_diff.earlier_series_dim_factor` option. It links to the plain group
  when the side has no color to move.

  Parameters:
    `side`  The diff side to define:
            `name`          The name of the plain group to define.
            `dim-name`      The name of the dim group to define.
            `diff-group`    The name of the standard diff group to prefer.
            `accent-group`  The name of the semantic accent group to fall back
                            to."
  (let [diff-hl (resolved-hl side.diff-group)
        ?bg (or diff-hl.bg (accent-bg side.accent-group))
        opts (config.get)
        dim-factor opts.range_diff.earlier_series_dim_factor
        hl-opts (if diff-hl.bg {:link side.diff-group}
                    ?bg {:bg ?bg}
                    {:link side.diff-group})
        dim-hl-opts (if ?bg {:bg (color.blend ?bg (normal-bg) dim-factor)}
                        {:link side.name})]
    (vim.api.nvim_set_hl 0 side.name hl-opts)
    (vim.api.nvim_set_hl 0 side.dim-name dim-hl-opts)))

(fn first-with-fg [groups]
  "Find the first of several highlight groups that sets a foreground.

  Parameters:
    `groups`  The names of the groups to try, in order of preference.

  Returns the name of the group, or nil when none of them sets one."
  (accumulate [?found nil _ group-name (ipairs groups) &until ?found]
    (let [hl (resolved-hl group-name)]
      (if hl.fg group-name))))

(fn define-text [name sources]
  "Define a group that colors text, by linking it to a standard group.

  A link is preferred to a color of the plugin's own, so that the text carries
  whatever the colorscheme says about it, including an attribute such as bold.
  The first source that sets a foreground wins. When none of them does, the
  group links to the first source arbitrarily.

  Parameters:
    `name`     The name of the group to define.
    `sources`  The standard groups to take the color from, in order of
               preference."
  (vim.api.nvim_set_hl 0 name
                       {:link (or (first-with-fg sources) (. sources 1))}))

(fn define-reversed [name sources]
  "Define a group that colors text by swapping the foreground and the
  background.

  Parameters:
    `name`     The name of the group to define.
    `sources`  The standard groups to take the color from, in order of
               preference."
  (case (first-with-fg sources)
    group (let [hl (resolved-hl group)]
            (set hl.reverse (not hl.reverse))
            (vim.api.nvim_set_hl 0 name hl))
    _ (vim.api.nvim_set_hl 0 name {:link (. sources 1)})))

(fn define-muted [name]
  "Define a group that is a muted version of 'Normal'.

  Parameters:
    `name`  The name of the group to define."
  (let [hl (resolved-hl :Normal)
        opts (config.get)
        mute-factor opts.range_diff.commit_pair_mute_factor]
    (if hl.fg
        (do
          (set hl.fg (color.blend hl.fg (normal-bg) mute-factor))
          (vim.api.nvim_set_hl 0 name hl))
        (vim.api.nvim_set_hl 0 name {:link :Comment}))))

(fn define []
  "Define every highlight group that the plugin uses."
  (define-line {:name add-group
                :dim-name add-dim-group
                :diff-group :DiffAdd
                :accent-group :Added})
  (define-line {:name delete-group
                :dim-name delete-dim-group
                :diff-group :DiffDelete
                :accent-group :Removed})
  (define-muted commit-group)
  (define-text commit-add-group commit-add-sources)
  (define-text commit-delete-group commit-delete-sources)
  (define-text patch-hunk-group hunk-sources)
  (define-text file-group file-sources)
  (define-reversed hunk-group hunk-sources)
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

{: add-group
 : delete-group
 : add-dim-group
 : delete-dim-group
 : commit-group
 : commit-add-group
 : commit-delete-group
 : hunk-group
 : patch-hunk-group
 : file-group
 : ensure
 : invalidate}
