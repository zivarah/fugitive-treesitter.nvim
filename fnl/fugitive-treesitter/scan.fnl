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

(fn body-line? [line]
  "Test whether a diff line belongs to the body of a hunk.

  Parameters:
    `line`  The diff line.

  Returns true for a context line, an added line, a removed line, or the
  `\\ No newline at end of file` marker."
  (let [sigil (char-at line 1)]
    (or (body-prefix? sigil) (= "\\" sigil))))

(fn hunk-header? [line]
  "Test whether a diff line is a hunk header.

  Parameters:
    `line`  The diff line.

  Returns true for a line that starts with `@`."
  (= "@" (char-at line 1)))

(fn hunk-body-end [lines start]
  "Find the end of the hunk body that starts at a position.

  Parameters:
    `lines`  The lines of the buffer, 1-indexed.
    `start`  The 1-based position of the first body line.

  Returns the 1-based position of the first line that is not a body line."
  (var i start)
  (while (and (<= i (length lines)) (body-line? (. lines i)))
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

(fn hunk-region [lines i state]
  "Make the region for the hunk body below a hunk header.

  A side that the change adds or deletes has no path of its own, and takes the
  path of the other side, so that a region always names a file for both sides.

  Parameters:
    `lines`  The lines of the buffer, 1-indexed.
    `i`      The 1-based position of the hunk header.
    `state`  The file state at the hunk header. See `scan`.

  Returns two values: the region, and the 1-based position to continue the scan
  from. The region is nil when there is no path or no body."
  (let [start (+ i 1)
        stop (hunk-body-end lines start)
        width (marker-width (. lines i))
        ?old-path (or state.old-path state.new-path)
        ?new-path (or state.new-path state.old-path)
        region (if (and ?old-path (> stop start))
                   {:first (- start 1)
                    :last (- stop 1)
                    :marker-width width
                    :text-col width
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

(fn git-file-state [line state]
  "Track the current file in `git`-format diff output.

  A `diff --git` header starts a new file, and the `---` and the `+++` header
  give the path of its old and its new side.

  Parameters:
    `line`   The diff line.
    `state`  The state after the line above.

  Returns the new state."
  (if (vim.startswith line "diff --git ")
      {}
      (vim.startswith line "--- ")
      (vim.tbl_extend :force state {:old-path (header-path line)})
      (vim.startswith line "+++ ")
      (vim.tbl_extend :force state {:new-path (header-path line)})
      state))

(fn status-file-state [line state]
  "Track the current file in the `:Git` status buffer, where a
  `<status> <path>` entry stands above the inline hunks of each file.

  Parameters:
    `line`   The status line.
    `state`  The state after the line above.

  Returns the new state."
  ;; A rename entry reads `old -> new`, and gives a path for each side. Any
  ;; other entry names one file, which stands for both sides.
  (case (line:match "^[A-Z?] (.+)$")
    entry (let [(?old-path ?new-path) (entry:match "^(.-) %-> (.+)$")]
            {:old-path (or ?old-path entry) :new-path (or ?new-path entry)})
    _ state))

(fn scan [lines track]
  "Find the hunk regions of a diff buffer.

  Parameters:
    `lines`  The lines of the buffer, 1-indexed.
    `track`  The function that tracks the current file. It takes a line and the
             state after the line above, and returns the new state. The
             `old-path` and `new-path` keys of a state hold the path of the file
             that the lines below belong to, on each side of the change. Either
             key is nil when that side has no file, or when the scan has not
             found a path yet.

  Returns the sequential table of regions."
  (let [regions []]
    (var state {})
    (var i 1)
    (while (<= i (length lines))
      (let [line (. lines i)]
        (if (hunk-header? line)
            (let [(region stop) (hunk-region lines i state)]
              (when region
                (table.insert regions region))
              (set i stop))
            (do
              (set state (track line state))
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
  (scan lines (if (= :fugitive filetype) status-file-state git-file-state)))

{: body-prefix? : line-kind : regions}
