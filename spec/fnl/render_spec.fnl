(local {: describe : it} (require :plenary.busted))
(local assert (require :luassert.assert))
(local render (require :fugitive-treesitter.render))
(local highlight (require :fugitive-treesitter.highlight))

(local ns (. (vim.api.nvim_get_namespaces) :fugitive-treesitter))

;; The priority that the plugin gives a line background. It is what tells one
;; apart from the marks above it, which color a treesitter capture or a part of
;; the buffer that carries no code.
(local priority-line 190)

(fn diff-buffer [filetype lines]
  "Make a scratch buffer that holds diff lines.

  Parameters:
    `filetype`  The filetype to set on the buffer.
    `lines`     The lines to put in it.

  Returns the buffer number."
  (let [buf (vim.api.nvim_create_buf false true)]
    (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
    (vim.api.nvim_set_option_value :filetype filetype {: buf})
    buf))

(fn marks [buf]
  "Collect the plugin's extmarks from a buffer.

  Parameters:
    `buf`  The buffer number.

  Returns a sequential table of
  `{:row :col :end-col :hl-group :hl-eol :line-hl-group :priority}`."
  (icollect [_ mark (ipairs (vim.api.nvim_buf_get_extmarks buf ns 0 -1
                                                           {:details true}))]
    (let [[_ row col details] mark]
      {: row
       : col
       :end-col details.end_col
       :hl-group details.hl_group
       :hl-eol details.hl_eol
       :line-hl-group details.line_hl_group
       :priority details.priority})))

(fn capture? [mark]
  "Test whether a mark colors one treesitter capture, rather than a diff line.

  Parameters:
    `mark`  The mark. See `marks`.

  Returns true for a mark whose group is a capture group."
  (and mark.hl-group (vim.startswith mark.hl-group "@")))

(fn colored-parts-on [buf row]
  "Collect the parts of one row that the plugin colors, other than a treesitter
  capture.

  Parameters:
    `buf`  The buffer number.
    `row`  The 0-based row.

  Returns a sequential table of `{:text :hl-group}`, in column order, where
  `text` is the text that the mark covers."
  (let [line (. (vim.api.nvim_buf_get_lines buf row (+ row 1) false) 1)]
    (icollect [_ mark (ipairs (marks buf))]
      (if (and (= row mark.row) mark.hl-group (not (capture? mark)))
          {:text (string.sub line (+ mark.col 1) mark.end-col)
           :hl-group mark.hl-group}))))

(fn background? [mark]
  "Test whether a mark colors the background of a diff line.

  Parameters:
    `mark`  The mark. See `marks`.

  Returns true for a mark at the priority of a line background."
  (= priority-line mark.priority))

(fn background-on [buf row]
  "Find the mark that colors the background of one row.

  Parameters:
    `buf`  The buffer number.
    `row`  The 0-based row.

  Returns the mark. See `marks`. Returns nil for a row that has no background."
  (accumulate [?found nil _ mark (ipairs (marks buf))]
    (if (and (= row mark.row) (background? mark)) mark ?found)))

(fn line-groups [buf]
  "Collect the line background of each row that has one.

  Parameters:
    `buf`  The buffer number.

  Returns a table from 0-based row to highlight group name."
  (collect [_ mark (ipairs (marks buf))]
    (if (background? mark)
        (values mark.row mark.hl-group))))

(fn captures-on [buf row]
  "Collect the treesitter captures placed on one row.

  Parameters:
    `buf`  The buffer number.
    `row`  The 0-based row.

  Returns a table from captured text position `col..end-col` to group name."
  (let [lines (vim.api.nvim_buf_get_lines buf row (+ row 1) false)
        line (. lines 1)]
    (collect [_ mark (ipairs (marks buf))]
      (if (and (= row mark.row) (capture? mark))
          (values (string.sub line (+ mark.col 1) mark.end-col) mark.hl-group)))))

(fn duplicate-captures-on [buf row]
  "Find the treesitter captures that cover the same text twice on one row.

  Parameters:
    `buf`  The buffer number.
    `row`  The 0-based row.

  Returns a sequential table of `col:end-col:group` keys, one entry for each
  mark past the first that covers the same text with the same group."
  (let [seen {}
        duplicates []]
    (each [_ mark (ipairs (marks buf))]
      (when (and (= row mark.row) (capture? mark))
        (let [key (string.format "%d:%d:%s" mark.col mark.end-col mark.hl-group)]
          (if (. seen key)
              (table.insert duplicates key)
              (set (. seen key) true)))))
    duplicates))

(local one-file ["diff --git a/a.lua b/a.lua"
                 "--- a/a.lua"
                 "+++ b/a.lua"
                 "@@ -1,3 +1,3 @@"
                 " local m = {}"
                 "-local timeout = 30"
                 "+local timeout = 60"
                 " return m"])

(describe :buffer
          (fn []
            (it "colors added and removed lines but not context lines"
                (fn []
                  (let [buf (diff-buffer :git one-file)]
                    (render.buffer buf)
                    (assert.same {5 highlight.delete-group
                                  6 highlight.add-group}
                                 (line-groups buf)))))
            (it "ends the line background where the line ends"
                (fn []
                  ;; Neither `hl_eol` nor a `line_hl_group`, which would both
                  ;; fill the rest of the screen line. A `line_hl_group` also
                  ;; wins over any `hl_group` above it, whatever the priorities
                  ;; say.
                  (let [buf (diff-buffer :git one-file)
                        removed (. one-file 6)]
                    (render.buffer buf)
                    (each [_ mark (ipairs (marks buf))]
                      (assert.is_nil mark.line-hl-group)
                      (assert.is_falsy mark.hl-eol))
                    (let [background (background-on buf 5)]
                      (assert.equals highlight.delete-group background.hl-group)
                      (assert.equals 0 background.col)
                      (assert.equals (length removed) background.end-col)))))
            (it "colors a line that holds nothing but its marker"
                (fn []
                  ;; The background never gets narrower than the marker, so an
                  ;; added empty line still shows a color.
                  (let [buf (diff-buffer :git
                                         ["diff --git a/a.lua b/a.lua"
                                          "--- a/a.lua"
                                          "+++ b/a.lua"
                                          "@@ -1,2 +1,3 @@"
                                          " local m = {}"
                                          "+"
                                          " return m"])]
                    (render.buffer buf)
                    (let [background (background-on buf 5)]
                      (assert.equals highlight.add-group background.hl-group)
                      (assert.equals 0 background.col)
                      (assert.equals 1 background.end-col)))))
            (it "colors an ordinary diff line with one mark from its marker on"
                (fn []
                  ;; An ordinary diff shows one series, so no column in front of
                  ;; the marker says which series holds the line, and there is
                  ;; nothing to color apart.
                  (let [buf (diff-buffer :git one-file)]
                    (render.buffer buf)
                    (assert.same [{:text "-local timeout = 30"
                                   :hl-group highlight.delete-group}]
                                 (colored-parts-on buf 5)))))
            (it "places treesitter captures shifted past the diff marker"
                (fn []
                  (let [buf (diff-buffer :git one-file)]
                    (render.buffer buf)
                    ;; The captures land on the code, not on the sigil.
                    (assert.equals "@number" (. (captures-on buf 5) :30))
                    (assert.equals "@number" (. (captures-on buf 6) :60))
                    (assert.equals "@keyword" (. (captures-on buf 5) :local)))))
            (it "highlights a fugitive status buffer"
                (fn []
                  (let [buf (diff-buffer :fugitive
                                         ["Head: main"
                                          "Unstaged (1)"
                                          "M a.lua"
                                          "@@ -1,2 +1,2 @@"
                                          "-local timeout = 30"
                                          "+local timeout = 60"])]
                    (render.buffer buf)
                    (assert.same {4 highlight.delete-group
                                  5 highlight.add-group}
                                 (line-groups buf))
                    (assert.equals "@number" (. (captures-on buf 4) :30)))))
            (it "highlights a combined diff in a status buffer"
                (fn []
                  ;; Fugitive inlines a combined diff for a conflicted file. Its
                  ;; body lines carry one marker per parent, so the code starts
                  ;; two columns in.
                  (let [buf (diff-buffer :fugitive
                                         ["Unstaged (1)"
                                          "U a.lua"
                                          "@@@ -1,3 -1,3 +1,3 @@@"
                                          "  local m = {}"
                                          "- local timeout = 30"
                                          " -local timeout = 45"
                                          "++local timeout = 60"
                                          "  return m"])]
                    (render.buffer buf)
                    (assert.same {4 highlight.delete-group
                                  5 highlight.delete-group
                                  6 highlight.add-group}
                                 (line-groups buf))
                    ;; Both markers are stripped, so `local` is a keyword rather
                    ;; than a variable, and no capture lands on a marker.
                    (assert.equals "@keyword" (. (captures-on buf 6) :local))
                    (assert.equals "@number" (. (captures-on buf 6) :60))
                    (assert.equals "@number" (. (captures-on buf 4) :30))
                    (assert.is_nil (. (captures-on buf 6) "+")))))
            (it "replaces the highlights rather than stacking them"
                (fn []
                  (let [buf (diff-buffer :git one-file)]
                    (render.buffer buf)
                    (let [before (length (marks buf))]
                      (render.buffer buf)
                      (assert.equals before (length (marks buf)))))))
            (it "colors past an empty context line"
                (fn []
                  ;; Under `diff.suppressBlankEmpty` git writes a blank context
                  ;; line with no leading space. Everything below it still
                  ;; belongs to the hunk.
                  (let [buf (diff-buffer :git
                                         ["diff --git a/a.lua b/a.lua"
                                          "--- a/a.lua"
                                          "+++ b/a.lua"
                                          "@@ -1,4 +1,4 @@"
                                          " local m = {}"
                                          ""
                                          "-local timeout = 30"
                                          "+local timeout = 60"])]
                    (render.buffer buf)
                    (assert.same {6 highlight.delete-group
                                  7 highlight.add-group}
                                 (line-groups buf))
                    (assert.equals "@number" (. (captures-on buf 6) :30)))))
            (it "still colors lines when the language has no parser"
                (fn []
                  (let [buf (diff-buffer :git
                                         ["diff --git a/a.zzunknown b/a.zzunknown"
                                          "--- a/a.zzunknown"
                                          "+++ b/a.zzunknown"
                                          "@@ -1 +1 @@"
                                          "-old text"
                                          "+new text"])]
                    (render.buffer buf)
                    (assert.same {4 highlight.delete-group
                                  5 highlight.add-group}
                                 (line-groups buf)))))
            (it "does nothing to a buffer with no hunk"
                (fn []
                  (let [buf (diff-buffer :git
                                         ["commit abc123" "Author: Nobody"])]
                    (render.buffer buf)
                    (assert.equals 0 (length (marks buf))))))))

(describe "per-side parsing"
          (fn []
            (it "keeps the other side's lines out of the parse"
                (fn []
                  ;; Interleaved, the two `function` lines share one `end`, the
                  ;; parse gives up over the removed line, and its `function`
                  ;; keyword gets no capture at all. Split, each side is a whole
                  ;; function.
                  (let [buf (diff-buffer :git
                                         ["diff --git a/a.lua b/a.lua"
                                          "--- a/a.lua"
                                          "+++ b/a.lua"
                                          "@@ -1,3 +1,3 @@"
                                          "-function foo(a)"
                                          "+function foo(a, b)"
                                          "   return a"
                                          " end"])]
                    (render.buffer buf)
                    (assert.equals "@keyword.function"
                                   (. (captures-on buf 4) :function))
                    (assert.equals "@keyword.function"
                                   (. (captures-on buf 5) :function)))))
            (it "parses each side of a rename with its own parser"
                (fn []
                  (let [buf (diff-buffer :git
                                         ["diff --git a/a.lua b/a.c"
                                          "similarity index 50%"
                                          "rename from a.lua"
                                          "rename to a.c"
                                          "--- a/a.lua"
                                          "+++ b/a.c"
                                          "@@ -1 +1 @@"
                                          "-local x = 1"
                                          "+int x = 1;"])]
                    (render.buffer buf)
                    ;; The lua parser makes `local` a keyword. The c parser
                    ;; would read it as a type name instead.
                    (assert.equals "@keyword" (. (captures-on buf 7) :local))
                    ;; The c parser makes `int` a builtin type. The lua parser
                    ;; would read it as a plain variable instead.
                    (assert.equals "@type.builtin" (. (captures-on buf 8) :int)))))
            (it "colors a context line once, not once per side"
                (fn []
                  (let [buf (diff-buffer :git one-file)]
                    (render.buffer buf)
                    (assert.same [] (duplicate-captures-on buf 4))
                    (assert.same [] (duplicate-captures-on buf 7))
                    ;; The context lines still get their captures.
                    (assert.equals "@keyword" (. (captures-on buf 4) :local))
                    (assert.equals "@keyword.return"
                                   (. (captures-on buf 7) :return)))))
            (it "colors an injected language inside a hunk"
                (fn []
                  ;; The markdown parser injects lua into the fenced block, so
                  ;; the code inside it gets lua captures rather than none.
                  (let [buf (diff-buffer :git
                                         ["diff --git a/a.md b/a.md"
                                          "--- a/a.md"
                                          "+++ b/a.md"
                                          "@@ -1,3 +1,3 @@"
                                          " ```lua"
                                          "-local timeout = 30"
                                          "+local timeout = 60"
                                          " ```"])]
                    (render.buffer buf)
                    (assert.equals "@keyword" (. (captures-on buf 5) :local))
                    (assert.equals "@number" (. (captures-on buf 6) :60)))))
            (it "colors a side whose file has no parser"
                (fn []
                  ;; The new side has no parser, which must not stop the old
                  ;; side from being highlighted.
                  (let [buf (diff-buffer :git
                                         ["diff --git a/a.lua b/a.zzunknown"
                                          "--- a/a.lua"
                                          "+++ b/a.zzunknown"
                                          "@@ -1 +1 @@"
                                          "-local x = 1"
                                          :+whatever])]
                    (render.buffer buf)
                    (assert.equals "@keyword" (. (captures-on buf 4) :local))
                    ;; The added line keeps its line background, but gets no
                    ;; capture of its own.
                    (assert.is_nil (. (captures-on buf 5) :whatever)))))))

;; A range-diff indents each patch by four columns and puts one marker of its
;; own in front of it. Here `-+` is the line that only the old series adds, and
;; `++` the line that replaces it in the new series.
(local one-pair [" 1:  1111111 ! 1:  2222222 fix: something"
                 "      ## a.lua ##"
                 "     @@"
                 "      local m = {}"
                 "     -local timeout = 30"
                 "    -+local timeout = 45"
                 "    ++local timeout = 60"
                 "      return m"])

(describe "range-diff output"
          (fn []
            (it "colors the lines by the marker of the patch"
                (fn []
                  ;; The inner marker says whether the patch adds or removes the
                  ;; line, so it picks the group. The outer marker says which
                  ;; series holds it, so it picks the plain or the dim group.
                  (let [buf (diff-buffer :git one-pair)]
                    (render.buffer buf)
                    (assert.same {4 highlight.delete-group
                                  5 highlight.add-dim-group
                                  6 highlight.add-group}
                                 (line-groups buf)))))
            (it "colors the marker of the series apart from the rest of the line"
                (fn []
                  ;; The old series holds row 5, and the patch of that series
                  ;; adds the line. So the marker carries the removed color and
                  ;; everything after it carries the added one.
                  (let [buf (diff-buffer :git one-pair)]
                    (render.buffer buf)
                    (assert.same [{:text "-" :hl-group highlight.delete-group}
                                  {:text "+local timeout = 45"
                                   :hl-group highlight.add-dim-group}]
                                 (colored-parts-on buf 5)))))
            (it "leaves the marker of a line that both series hold uncolored"
                (fn []
                  ;; Row 4 is ` -`: both series hold it, so there is no series
                  ;; to mark, and the removed color starts at the inner marker.
                  (let [buf (diff-buffer :git one-pair)]
                    (render.buffer buf)
                    (assert.same [{:text "-local timeout = 30"
                                   :hl-group highlight.delete-group}]
                                 (colored-parts-on buf 4)))))
            (it "colors the entry that pairs two commits"
                (fn []
                  ;; The subject gets no part of its own, so it keeps the
                  ;; foreground of the editor.
                  (let [buf (diff-buffer :git one-pair)]
                    (render.buffer buf)
                    (assert.same [{:text "1:  1111111"
                                   :hl-group highlight.commit-delete-group}
                                  {:text "!" :hl-group highlight.commit-group}
                                  {:text "1:  2222222"
                                   :hl-group highlight.commit-add-group}]
                                 (colored-parts-on buf 0)))))
            (it "colors the hunk header of a patch and the heading above it"
                (fn []
                  ;; The heading stands in for the `diff --git` header of an
                  ;; ordinary diff, and names the file that follows.
                  (let [buf (diff-buffer :git one-pair)]
                    (render.buffer buf)
                    (assert.same [{:text :a.lua :hl-group highlight.file-group}]
                                 (colored-parts-on buf 1))
                    (assert.same [{:text "@@"
                                   :hl-group highlight.patch-hunk-group}]
                                 (colored-parts-on buf 2)))))
            (it "colors the marker of a line that no hunk covers"
                (fn []
                  ;; The commit message section holds prose rather than code, so
                  ;; there is no hunk to parse and no background to place. The
                  ;; marker still says which series holds the line.
                  (let [buf (diff-buffer :git
                                         [" 1:  1111111 ! 1:  2222222 fix: x"
                                          "    @@ Commit message"
                                          "    -    fix: old subject"
                                          "    +    fix: new subject"])]
                    (render.buffer buf)
                    (assert.same {} (line-groups buf))
                    (assert.same [{:text "-" :hl-group highlight.delete-group}]
                                 (colored-parts-on buf 2))
                    (assert.same [{:text "+" :hl-group highlight.add-group}]
                                 (colored-parts-on buf 3)))))
            (it "dims only the lines that the earlier series alone holds"
                (fn []
                  ;; `--` and `-+` belong to the old series alone, so both are
                  ;; dimmed. A line that both series hold, or that only the new
                  ;; series holds, keeps the plain group.
                  (let [buf (diff-buffer :git
                                         [" 1:  1111111 ! 1:  2222222 fix: x"
                                          "      ## a.lua ##"
                                          "     @@"
                                          "    --local dropped = 1"
                                          "    -+local old_add = 2"
                                          "     -local shared_del = 3"
                                          "    ++local new_add = 4"
                                          "    +-local new_del = 5"])]
                    (render.buffer buf)
                    (assert.same {3 highlight.delete-dim-group
                                  4 highlight.add-dim-group
                                  5 highlight.delete-group
                                  6 highlight.add-group
                                  7 highlight.delete-group}
                                 (line-groups buf)))))
            (it "parses each series apart from the other"
                (fn []
                  ;; Together the two added lines are not valid code, so a
                  ;; single parse loses the captures of at least one of them.
                  (let [buf (diff-buffer :git one-pair)]
                    (render.buffer buf)
                    (assert.equals "@number" (. (captures-on buf 5) :45))
                    (assert.equals "@number" (. (captures-on buf 6) :60))
                    (assert.equals "@keyword" (. (captures-on buf 5) :local))
                    (assert.equals "@keyword" (. (captures-on buf 6) :local)))))
            (it "strips both markers"
                (fn []
                  (let [buf (diff-buffer :git one-pair)]
                    (render.buffer buf)
                    (assert.equals "@number" (. (captures-on buf 4) :30))
                    (assert.is_nil (. (captures-on buf 6) "+"))
                    (assert.is_nil (. (captures-on buf 5) "-+")))))
            (it "colors a line that both series hold once"
                (fn []
                  ;; A context line takes part in the parse of both series, so
                  ;; only one of them may color it.
                  (let [buf (diff-buffer :git one-pair)]
                    (render.buffer buf)
                    (assert.same [] (duplicate-captures-on buf 3))
                    (assert.same [] (duplicate-captures-on buf 4))
                    (assert.same [] (duplicate-captures-on buf 7))
                    (assert.equals "@keyword" (. (captures-on buf 3) :local))
                    (assert.equals "@keyword.return"
                                   (. (captures-on buf 7) :return)))))))

(describe :clear
          (fn []
            (it "removes every highlight the plugin placed"
                (fn []
                  (let [buf (diff-buffer :git one-file)]
                    (render.buffer buf)
                    (assert.is_true (< 0 (length (marks buf))))
                    (render.clear buf)
                    (assert.equals 0 (length (marks buf))))))))
