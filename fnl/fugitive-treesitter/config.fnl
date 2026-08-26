;;; Plugin options.

(local defaults {:max_lines 10000
                 :derived_background {:saturation 0.35
                                      :lightness {:dark 0.18 :light 0.85}}
                 :range_diff {:enabled true
                              :earlier_series_dim_factor 0.4
                              :commit_pair_mute_factor 0.4}})

(var options (vim.deepcopy defaults))

(fn unknown-keys [opts known ?prefix]
  "Identify keys in `opts` that aren't recognized by this plugin.

  Parameters:
    `opts`    The options to check.
    `known`   The table of options that the plugin has, at the same depth.
    `?prefix` The dotted path of `opts` so far, pass nil for the top-level call.

  Returns a sequential table of unrecognized option paths."
  (let [unknown []]
    (each [key value (pairs opts)]
      (let [path (if ?prefix (.. ?prefix key) key)
            ?known (. known key)]
        (if (= nil ?known)
            (table.insert unknown path)
            (and (= :table (type ?known)) (= :table (type value)))
            (each [_ name (ipairs (unknown-keys value ?known (.. path ".")))]
              (table.insert unknown name)))))
    unknown))

(fn validate-options [opts known ?prefix]
  "Check that every recognized option holds a value of the right type.

  The type an option takes is the type of its default, so the defaults are the
  only place that records it. An unrecognized key is skipped, because
  `unknown-keys` reports those on its own.

  Parameters:
    `opts`    The options to check.
    `known`   The table of options that the plugin has, at the same depth.
    `?prefix` The dotted path of `opts` so far, pass nil for the top-level call.

  Raises an error that names the option when one holds a value of the wrong
  type."
  (let [prefix (or ?prefix "")]
    (each [key value (pairs opts)]
      (case (. known key)
        expected (let [path (.. prefix key)]
                   (vim.validate path value (type expected))
                   (when (= :table (type expected))
                     (validate-options value expected (.. path "."))))))))

(fn setup [?opts]
  "Configure the plugin by merging `?opts` with the default options.

  Parameters:
    `?opts`  The user options. See |fugitive-treesitter-config|."
  (vim.validate :opts ?opts :table true)
  (let [opts (or ?opts {})
        unknown (unknown-keys opts defaults)]
    (when (> (length unknown) 0)
      (vim.notify (.. "fugitive-treesitter: unknown options specified: "
                      (table.concat unknown ", "))
                  vim.log.levels.WARN))
    (let [merged (vim.tbl_deep_extend :force defaults (or ?opts {}))]
      (validate-options merged defaults)
      (set options merged))))

(fn get []
  "Get the plugin options.

  Returns the currently configured options, or the defaults if `setup` has not
  run."
  options)

{: setup : get}
