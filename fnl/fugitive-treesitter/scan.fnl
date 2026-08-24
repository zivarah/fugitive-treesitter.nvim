;;; Finding the hunk regions of a diff buffer.
;;;
;;; A region is one hunk body together with the path of the file on each side of
;;; the change. The paths matter because they decide which treesitter parser
;;; reads each side of the hunk, and a rename can give the two sides different
;;; filetypes.

(local {: char-at} (require :fugitive-treesitter.lib.str))

(fn body-prefix? [sigil]
  "Test whether a sigil character is the marker of a hunk body line.

  An empty line counts as a blank context line. Git writes a blank context line
  as a single space, but it writes it as an empty line under
  `diff.suppressBlankEmpty`.

  Parameters:
    `sigil`  The first byte of a line, or an empty string for an empty line.

  Returns true for the marker of a context line, an added line, or a removed
  line."
  (or (= "+" sigil) (= "-" sigil) (= " " sigil) (= "" sigil)))

(fn line-kind [prefix]
  "Classify a hunk body line by its diff marker.

  A combined diff writes one marker per parent, so a marker can be several
  characters wide. A `+` in any column means the result holds the line and that
  parent does not, and a `-` in any column means a parent holds the line and the
  result does not. The two never appear together, because a line is either in
  the result or not. See |diff-format|.

  Every column of `prefix` therefore describes the same line, from the point of
  view of one parent. The columns are peers, so their order carries no meaning.
  Do not use this function for a format whose columns are nested levels instead,
  because collapsing those loses the distinction between them.

  Parameters:
    `prefix`  The diff marker of the line, one character per parent. See
              `body-prefix?`.

  Returns `:add` for an added line, `:delete` for a removed line, or `:context`
  for a line that both sides of the change share."
  (if (prefix:find "+" 1 true) :add
      (prefix:find "-" 1 true) :delete
      :context))

(fn body-line? [?line]
  "Test whether a normalized hunk candidate belongs to the body of a hunk.

  Parameters:
    `?line`  The normalized hunk candidate, or nil when the buffer line cannot
             belong to a hunk.

  Returns true for a context line, an added line, a removed line, or the
  `\\ No newline at end of file` marker. Returns false for any other value,
  including nil."
  (if ?line
      (let [sigil (char-at ?line 1)]
        (or (body-prefix? sigil) (= "\\" sigil)))
      false))

(fn hunk-header? [?line]
  "Test whether a normalized hunk candidate is a hunk header.

  Parameters:
    `?line`  The normalized hunk candidate, or nil when the buffer line cannot
             belong to a hunk.

  Returns true for a line that starts with `@`. Returns false for any other
  value, including nil."
  (and (not= nil ?line) (= "@" (char-at ?line 1))))

(fn body-row? [format line]
  "Test whether a buffer line contains a hunk body line.

  Parameters:
    `format`  The diff format. See `formats`.
    `line`    The buffer line.

  Returns true if the line belongs to the body of a hunk."
  (body-line? (format.hunk-line line)))

(fn hunk-body-end [lines start format]
  "Find the end of the hunk body that starts at a position.

  Parameters:
    `lines`   The lines of the buffer, 1-indexed.
    `start`   The 1-based position of the first body line.
    `format`  The diff format. See `formats`.

  Returns the 1-based position of the first line that is not a body line."
  (var i start)
  (while (and (<= i (length lines)) (body-row? format (. lines i)))
    (set i (+ i 1)))
  i)

(fn marker-width [header]
  "Find how many marker characters each body line of a hunk carries.

  Parameters:
    `header`  The hunk header line.

  Returns 1 for an ordinary diff. Returns one per parent for a combined diff,
  whose header carries one `@` per parent plus one. See |diff-format|."
  (-> (length (header:match "^@+"))
      (- 1)
      (math.max 1)))

(fn hunk-region [lines i header state format]
  "Make the region for the hunk body below a hunk header.

  A side that the change adds or deletes has no path of its own, and takes the
  path of the other side, so that a region always names a file for both sides.

  Parameters:
    `lines`   The lines of the buffer, 1-indexed.
    `i`       The 1-based position of the hunk header.
    `header`  The normalized hunk header.
    `state`   The file state at the hunk header. See `scan`.
    `format`  The diff format. See `formats`.

  Returns two values: the region, and the 1-based position to continue the scan
  from. The region is nil when there is no path or no body."
  (let [start (+ i 1)
        stop (hunk-body-end lines start format)
        width (marker-width header)
        ?old-path (or state.old-path state.new-path)
        ?new-path (or state.new-path state.old-path)
        region (if (and ?old-path (> stop start))
                   {:first (- start 1)
                    :last (- stop 1)
                    :marker-width width
                    :text-col (+ format.text-offset width)
                    :old-path ?old-path
                    :new-path ?new-path})]
    (values region stop)))

(fn header-path [line]
  "Get the file path from a `---` or a `+++` diff header.

  Parameters:
    `line`  The header line.

  Returns the path, or nil when the file is absent from that side of the diff,
  which git writes as `/dev/null`."
  (let [path (line:sub 5)]
    (if (not= path :/dev/null)
        (or (path:match "^%a/(.+)$") path))))

(fn parse-git-file-header [line state]
  "Parse a file header line in `git`-format diff output.

  Note that this *could* have a false positive on a real hunk content line if
  that line starts with '--- ' or '+++ '. Avoid calling it on a line that is
  inside a hunk.

  Parameters:
    `line`   The diff line.
    `state`  The state after the line above.

  Returns the state after the header, or nil if `line` is not a file header."
  (if (vim.startswith line "diff --git ")
      {}
      (vim.startswith line "--- ")
      (vim.tbl_extend :force state {:old-path (header-path line)})
      (vim.startswith line "+++ ")
      (vim.tbl_extend :force state {:new-path (header-path line)})))

(fn parse-status-file-header [line _state]
  "Parse a file header in the `:Git` status buffer, where a
  `<status> <path>` entry stands above the inline hunks of each file.

  Parameters:
    `line`    The status line.
    `_state`  The state after the line above. This format does not use it.

  Returns the state after the header, or nil if `line` is not a file header."
  ;; A rename entry reads `old -> new`, and gives a path for each side. Any
  ;; other entry names one file, which stands for both sides.
  (case (line:match "^[A-Z?] (.+)$")
    entry (let [(?old-path ?new-path) (entry:match "^(.-) %-> (.+)$")]
            {:old-path (or ?old-path entry) :new-path (or ?new-path entry)})
    _ nil))

(fn unwrapped-hunk-line [line]
  "Normalize a buffer line for hunk syntax checks in an unwrapped format.

  Parameters:
    `line`  The buffer line.

  Returns the line unchanged."
  line)

;; How to read each diff format that the plugin handles.
;;
;;   `hunk-line`          Normalize a buffer line for hunk syntax checks. Return
;;                        nil when the line cannot belong to a hunk. Non-nil
;;                        means that the line could be a header or a body line
;;                        (to be determined later).
;;   `parse-file-header`  Parse a file header and return the new file state, or
;;                        nil when the buffer line is not a file header.
;;   `text-offset`        The 0-based buffer column where the diff line starts.
(local formats {:git {:hunk-line unwrapped-hunk-line
                      :parse-file-header parse-git-file-header
                      :text-offset 0}
                :fugitive {:hunk-line unwrapped-hunk-line
                           :parse-file-header parse-status-file-header
                           :text-offset 0}})

(fn scan [lines format]
  "Find the hunk regions of a diff buffer.

  The `parse-file-header` function of a format takes a buffer line and the state
  after the line above. It returns the state after the header, or nil when the
  line is not a header. The `old-path` and `new-path` keys hold the path of the
  file that the lines below belong to, on each side of the change. Either key is
  nil when that side has no file, or when the scan has not found a path yet.

  The scan calls `parse-file-header` only between hunks. It skips each hunk body
  as a unit because a body line can have the same syntax as a file header (e.g.
  a '--- ' prefix to a line in a git diff could be the header line for the old
  file, or it could be a line that was removed that happened to start with
  '-- '.

  Parameters:
    `lines`   The lines of the buffer, 1-indexed.
    `format`  The diff format. See `formats`.

  Returns the sequential table of regions."
  (let [regions []]
    (var state {})
    (var i 1)
    (while (<= i (length lines))
      (let [line (. lines i)
            ?hunk-line (format.hunk-line line)]
        (if (hunk-header? ?hunk-line)
            (let [(region stop) (hunk-region lines i ?hunk-line state format)]
              (when region
                (table.insert regions region))
              (set i stop))
            (let [?new-state (format.parse-file-header line state)]
              (when ?new-state
                (set state ?new-state))
              (set i (+ i 1))))))
    regions))

(fn regions [lines filetype]
  "Find the hunk regions of a diff buffer.

  Parameters:
    `lines`     The lines of the buffer, 1-indexed.
    `filetype`  The filetype of the buffer. `fugitive` selects the status
                buffer format, and any other value selects `git`-format diff
                output.

  Returns a sequential table of regions, in buffer order. A region holds:
    `first`         The 0-based first row of the hunk body.
    `last`          The 0-based row just past the hunk body.
    `marker-width`  The number of marker characters that each body line
                    carries. See `marker-width`.
    `text-col`      The 0-based column where the text of a body line starts.
                    The marker characters are the `marker-width` columns that
                    end there.
    `old-path`      The path of the file before the change.
    `new-path`      The path of the file after the change. This differs from
                    `old-path` only for a rename.

  Returns an empty table when the buffer holds no hunk that belongs to a known
  file."
  (scan lines (if (= :fugitive filetype) formats.fugitive formats.git)))

{: body-prefix? : line-kind : regions}
