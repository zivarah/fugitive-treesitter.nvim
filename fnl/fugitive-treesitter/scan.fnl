;;; Finding the hunk regions of a diff buffer.
;;;
;;; A region is one hunk body together with the path of the file on each side of
;;; the change. The paths matter because they decide which treesitter parser
;;; reads each side of the hunk, and a rename can give the two sides different
;;; filetypes.

(local {: char-at} (require :fugitive-treesitter.lib.str))
(local config (require :fugitive-treesitter.config))

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
                    :series format.series
                    :series-width format.series-width
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

;; The sections that a range-diff writes in place of a file. They contain prose
;; rather than code, so they get no path and no parser.
(local range-diff-pseudo-files {:Metadata true "Commit message" true})

(fn range-diff-header-pattern [old operator new]
  "Builds a range-diff header pattern that returns the positions of the various components.

  Parameters:
    `operator`  The operator separating the two sides
    `old`       The pattern of the side that names the commit of the earlier
                series.
    `new`       The pattern of the side that names the commit of the later
                series.

  Returns the pattern capturing the position where each part of the entry starts
  and the position just past its end, for the old side, the operator and the new
  side in turn."
  (.. "^%s*()" old "()%s+()" operator "()%s+()" new "()"))

(local range-diff-header-patterns
       (let [commit-side "%d+:%s+%x%x%x%x%x%x%x+"
             missing-side "%-+:%s+%-%-%-%-%-%-%-+"]
         {:same (range-diff-header-pattern commit-side "=" commit-side)
          :changed (range-diff-header-pattern commit-side "!" commit-side)
          :dropped (range-diff-header-pattern commit-side "<" missing-side)
          :added (range-diff-header-pattern missing-side ">" commit-side)}))

(fn range-diff-patch-line [line]
  "Get the patch line from a range-diff buffer line.

  Patch lines are all lines within one range-diff header that are indented by the four
  columns that range-diff uses, including '@@' hunk markers and '##' file
  markers. For the lines that have one, the first series marker (the first of
  the two '+'/'-'/' ' characters) is stripped.

  Parameters:
    `line`  The buffer line.

  Returns the patch line, which starts with its own marker (not the outer series
  marker), or nil when the buffer line belongs to the range-diff rather than to
  a patch. A range-diff header entry gives nil."
  (if (vim.startswith line "    ")
      (let [rest (string.sub line 5)]
        (if (vim.startswith rest "@@") rest
            (body-prefix? (char-at rest 1)) (string.sub rest 2)))))

(fn range-diff-file-header? [patch-line]
  "Determine if the patch line (normalized by `range-diff-patch-line`) is a
  range-diff file header like '[ +-]## <file> ##'"
  (not= nil (patch-line:match "^[ +-]## .+ ##$")))

(fn range-diff-hunk-line [line]
  "Normalize a range-diff buffer line for hunk syntax checks.

  Parameters:
    `line`  The buffer line.

  Returns a hunk candidate in patch coordinates, or nil when the buffer line
  cannot belong to a hunk. A `## path ##` file header gives nil so that it ends
  the hunk above it."
  (case (range-diff-patch-line line)
    patch-line (if (not (range-diff-file-header? patch-line)) patch-line)))

(fn range-diff-section-path [heading]
  "Get the file path out of the heading of a range-diff section.

  Parameters:
    `heading`  The heading of the section.

  Returns the path. Two things that a heading can carry besides the path are
  dropped:

    - a hunk header of the outer diff repeats the heading and appends the code
      around it after a colon, e.g. `src/retry.ts: export async function ...`
    - a heading notes a file that the patch creates or removes in brackets, e.g.
      `docs/retry.md (new)`."
  (pick-values 1 (-> heading
                     (string.gsub ":.*$" "")
                     (string.gsub "%s+%b()$" ""))))

(fn range-diff-section-state [heading]
  "Make the file state for the heading of a range-diff section.

  Parameters:
    `heading`  The heading of the section.

  Returns the state with both `old-path` and `new-path` set to the identified
  file path, or an empty state for a pseudofile like the commit message."
  (let [path (range-diff-section-path heading)]
    (if (. range-diff-pseudo-files path)
        {}
        {:old-path path :new-path path})))

(fn parse-range-diff-file-header [line _state]
  "Parse a file header in `git range-diff` output.

  A `## path ##` line starts a new file. A hunk header of the outer diff names
  the file too, and is the only place the path appears when the outer diff skips
  the `## path ##` line itself, which it does whenever that line is far enough
  above the first difference.

  Parameters:
    `line`    The buffer line.
    `_state`  The state after the line above. This format does not use it.

  Returns the state after the header, or nil if `line` is not a file header."
  (case (range-diff-patch-line line)
    patch-line (case (or (patch-line:match "^[ +-]## (.+) ##$")
                         (patch-line:match "^@@ (.+)$"))
                 heading (range-diff-section-state heading))))

(fn range-diff-header? [line]
  "Test whether a line is a range diff header (naming the pair of commits).

  Parameters:
    `line`  The buffer line.

  Returns true for a range-diff header."
  (accumulate [found? false _ pattern (pairs range-diff-header-patterns)
               &until found?]
    (not= nil (line:match pattern))))

(fn first-content-line [lines]
  "Get the first non-empty line of a buffer.

  Parameters:
    `lines`  The lines of the buffer, 1-indexed.

  Returns the line, or nil when every line is blank."
  (accumulate [?found nil _ line (ipairs lines) &until ?found]
    (if (not= "" (vim.trim line)) line)))

(fn range-diff? [lines]
  "Test whether a buffer contains `git range-diff` output.

  A range-diff has the `git` filetype, the same as ordinary diff output, so the
  format has to be told from the content.

  Parameters:
    `lines`  The lines of the buffer, 1-indexed.

  Returns true if the buffer has range-diff content."
  (case (first-content-line lines)
    line (range-diff-header? line)
    _ false))

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
;;   `series`             The series of patches that the format shows, which are
;;                        parsed apart from each other. A format that shows one
;;                        patch has one series, and every line belongs to it.
;;   `series-width`       The number of columns that are used to indicate which
;;                        series a line belongs to. Will be 0 for simple diffs
;;                        where there is just a single old vs. new patch.
(local formats {:git {:hunk-line unwrapped-hunk-line
                      :parse-file-header parse-git-file-header
                      :text-offset 0
                      :series [:context]
                      :series-width 0}
                :fugitive {:hunk-line unwrapped-hunk-line
                           :parse-file-header parse-status-file-header
                           :text-offset 0
                           :series [:context]
                           :series-width 0}
                :range-diff {:hunk-line range-diff-hunk-line
                             :parse-file-header parse-range-diff-file-header
                             :text-offset 5
                             :series [:delete :add]
                             :series-width 1}})

(fn buffer-format [lines filetype]
  "Choose the diff format to use for a buffer based on its content and filetype.

  Parameters:
    `lines`     The lines of the buffer, 1-indexed.
    `filetype`  The filetype of the buffer.

  Returns the format."
  (let [opts (config.get)]
    (case filetype
      :fugitive formats.fugitive
      :git (if (and opts.range_diff.enabled (range-diff? lines))
               formats.range-diff
               formats.git))))

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
            ?hunk-line (format.hunk-line line)
            ?new-state (format.parse-file-header line state)]
        (when ?new-state
          (set state ?new-state))
        (if (hunk-header? ?hunk-line)
            (let [(region stop) (hunk-region lines i ?hunk-line state format)]
              (when region
                (table.insert regions region))
              (set i stop))
            (set i (+ i 1)))))
    regions))

(fn regions [lines filetype]
  "Find the hunk regions of a diff buffer.

  Parameters:
    `lines`     The lines of the buffer, 1-indexed.
    `filetype`  The filetype of the buffer. `fugitive` selects the status
                buffer format. Any other value selects `git range-diff` output
                or `git`-format diff output, whichever the content looks like.

  Returns a sequential table of regions, in buffer order. A region holds:
    `first`         The 0-based first row of the hunk body.
    `last`          The 0-based row just past the hunk body.
    `marker-width`  The number of marker characters that each body line
                    carries. See `marker-width`.
    `text-col`      The 0-based column where the text of a body line starts.
                    The marker characters are the `marker-width` columns that
                    end there.
    `series`        The series of patches to parse apart from each other. See
                    `formats`.
    `series-width`  The number of columns, just before the marker, that say
                    which series a body line belongs to.
    `old-path`      The path of the file before the change.
    `new-path`      The path of the file after the change. This differs from
                    `old-path` only for a rename.

  Returns an empty table when the buffer holds no hunk that belongs to a known
  file."
  (scan lines (buffer-format lines filetype)))

{: body-prefix? : line-kind : regions}
