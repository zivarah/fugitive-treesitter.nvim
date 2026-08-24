(local {: describe : it} (require :plenary.busted))
(local assert (require :luassert.assert))
(local render (require :fugitive-treesitter.render))
(local highlight (require :fugitive-treesitter.highlight))

(local ns (. (vim.api.nvim_get_namespaces) :fugitive-treesitter))

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
  `{:row :col :end-col :hl-group :hl-eol :line-hl-group}`."
  (icollect [_ mark (ipairs (vim.api.nvim_buf_get_extmarks buf ns 0 -1
                                                           {:details true}))]
    (let [[_ row col details] mark]
      {: row
       : col
       :end-col details.end_col
       :hl-group details.hl_group
       :hl-eol details.hl_eol
       :line-hl-group details.line_hl_group})))

(fn line-groups [buf]
  "Collect the line background of each row that has one.

  A line background is the mark that reaches past the end of the text.

  Parameters:
    `buf`  The buffer number.

  Returns a table from 0-based row to highlight group name."
  (collect [_ mark (ipairs (marks buf))]
    (if mark.hl-eol
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
      (if (and (= row mark.row) mark.hl-group)
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
      (when (and (= row mark.row) mark.hl-group
                 (vim.startswith mark.hl-group "@"))
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
            (it "colors a line with hl_eol rather than with a line_hl_group"
                (fn []
                  ;; A `line_hl_group` background wins over any `hl_group`
                  ;; above it, whatever the priorities say.
                  (let [buf (diff-buffer :git one-file)]
                    (render.buffer buf)
                    (each [_ mark (ipairs (marks buf))]
                      (assert.is_nil mark.line-hl-group))
                    (assert.equals highlight.delete-group
                                   (. (line-groups buf) 5)))))
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
            (it "replaces the highlights rather than stacking them"
                (fn []
                  (let [buf (diff-buffer :git one-file)]
                    (render.buffer buf)
                    (let [before (length (marks buf))]
                      (render.buffer buf)
                      (assert.equals before (length (marks buf)))))))
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

(describe :clear
          (fn []
            (it "removes every highlight the plugin placed"
                (fn []
                  (let [buf (diff-buffer :git one-file)]
                    (render.buffer buf)
                    (assert.is_true (< 0 (length (marks buf))))
                    (render.clear buf)
                    (assert.equals 0 (length (marks buf))))))))
