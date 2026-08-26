;;; Putting the diff highlights on a buffer as extmarks.
;;;
;;; The hunk body is parsed without its diff markers, so every column that
;;; comes back from treesitter sits to the left of where it belongs in the
;;; buffer. Each extmark shifts back by the width of the marker to compensate.
;;; That width is one character for an ordinary diff, and one per parent for a
;;; combined diff.

(local {: char-at} (require :fugitive-treesitter.lib.str))
(local config (require :fugitive-treesitter.config))
(local highlight (require :fugitive-treesitter.highlight))
(local scan (require :fugitive-treesitter.scan))

(local ns (vim.api.nvim_create_namespace :fugitive-treesitter))

;; The priorities stack, so that the line background composites under the
;; treesitter syntax foreground rather than covering it.
;;
;; The stack only holds because every extmark uses `hl_group`. A `line_hl_group`
;; does not take part in this ordering at all: its background wins over any
;; `hl_group` above it, whatever the priorities say.
(local priority-line 190)
(local priority-syntax 210)

(fn set-extmark [buf row col opts]
  "Put one extmark on a buffer.

  Ignores an out-of-range position and any other error because a buffer can
  change between the scan and the render.

  Parameters:
    `buf`   The buffer number.
    `row`   The 0-based row.
    `col`   The 0-based column.
    `opts`  The extmark options. See |nvim_buf_set_extmark()|."
  (pcall vim.api.nvim_buf_set_extmark buf ns row col
         (vim.tbl_extend :force opts {:strict false})))

(fn marker? [marker]
  "Test whether a line belongs to a hunk body, from its marker characters.

  Parameters:
    `marker`  The marker characters of the line, one per parent for a combined
              diff.

  Returns true if every column holds a hunk body marker. An empty marker counts,
  because it comes from a blank context line."
  (faccumulate [body? true i 1 (length marker) &until (not body?)]
    (scan.body-prefix? (char-at marker i))))

(fn region-columns [region]
  "Identify the columns where different parts of a body line start.

  Parameters:
    `region`  The region. See `scan.regions`.

  Returns a table of 0-based columns:
    `series`  The first column of the marker that says which series holds the
              line. The same as `marker` for formats with only one series.
    `marker`  The first column of the marker indicating how the series changed
              the line.
    `text`    The first column of the actual source text of the line."
  (let [text region.text-col
        marker (- text region.marker-width)
        series (- marker region.series-width)]
    {: series : marker : text}))

(fn region-lines [buf-lines region]
  "Collect the hunk body lines of a region.

  Parameters:
    `buf-lines`  All the lines of the buffer, 1-indexed.
    `region`     The region. See `scan.regions`.

  Returns a sequential table of `{:row :col :series :kind :text}`. `row` is the
  0-based buffer row, `col` is the 0-based buffer column where `text` starts,
  `series` is the series that holds the line or `:context` when every series
  does, `kind` is the line kind (see `scan.line-kind`), and `text` is the line
  without its marker. A line that is not part of a hunk body is left out."
  (let [cols (region-columns region)]
    (fcollect [row region.first (- region.last 1)]
      (case (. buf-lines (+ row 1))
        line (let [marker (string.sub line (+ cols.marker 1) cols.text)
                   series (string.sub line (+ cols.series 1) cols.marker)
                   text (string.sub line (+ cols.text 1))]
               (if (marker? marker)
                   {: row
                    :col cols.text
                    :series (scan.line-kind series)
                    :kind (scan.line-kind marker)
                    : text}))))))

(fn series-lines [lines series context-owner?]
  "Collect the hunk body lines present in a given series.

  Parameters:
    `lines`           The hunk body lines. See `region-lines`.
    `series`          The series for which to collect lines.
    `context-owner?`  Whether this series owns highlighting for shared context
                      lines.

  Returns a sequential table of `{:row :col :kind :text :owned?}`, in buffer
  order. A line that every series holds is owned by the first series alone, so
  that it gets one set of captures rather than one per series."
  (icollect [_ line (ipairs lines)]
    (let [shared? (= :context line.series)]
      (if (or shared? (= series line.series))
          {:row line.row
           :col line.col
           :kind line.kind
           :text line.text
           :owned? (or (not shared?) context-owner?)}))))

(fn side-lines [lines kind paint-context?]
  "Reconstruct one side of a hunk body.

  A side holds its own changed lines together with every context line, so that
  the text reads as the file did on that side of the change. The two sides share
  their context lines, so only one of them colors those.

  Parameters:
    `lines`           The lines of one series. See `series-lines`.
    `kind`            The kind of the changed lines of the side, `:add` or
                      `:delete`. See `scan.line-kind`.
    `paint-context?`  Whether this side colors its context lines.

  Returns a sequential table of `{:row :col :text :paint?}`, in buffer order.
  `row` and `col` say where `text` starts in the buffer. A line with a false
  `paint?` will be painted by a different series/side."
  (icollect [_ line (ipairs lines)]
    (match line.kind
      kind {:row line.row :col line.col :text line.text :paint? line.owned?}
      :context {:row line.row
                :col line.col
                :text line.text
                :paint? (and paint-context? line.owned?)})))

(fn line-hl-group [kind series]
  "Get the highlight group that colors a whole diff line.

  Parameters:
    `kind`    The line kind. See `scan.line-kind`.
    `series`  The series that holds the line. See `region-lines`.

  Returns the name of the group, or nil for a context line. A line that only the
  earlier series of a range-diff holds gets a dim group, so that the series
  which matters now stands out from the one it replaced."
  (let [dim? (= :delete series)]
    (case kind
      :add (if dim? highlight.add-dim-group highlight.add-group)
      :delete (if dim? highlight.delete-dim-group highlight.delete-group))))

(fn apply-line-backgrounds [buf region lines]
  "Color the whole of each added and each removed line.

  Parameters:
    `buf`     The buffer number.
    `region`  The region that the lines belong to. See `scan.regions`.
    `lines`   The hunk body lines. See `region-lines`."
  (let [cols (region-columns region)]
    (each [_ {: row : kind : series : col : text} (ipairs lines)]
      (case (line-hl-group kind series)
        hl-group (set-extmark buf row cols.marker
                              {:end_col (+ col (length text))
                               :hl_group hl-group
                               :priority priority-line})))))

(fn resolve-lang [filepath]
  "Find the treesitter language of a file.

  Parameters:
    `filepath`  The path of the file.

  Returns the name of the language, or nil if the file has no known filetype or
  if the parser for its language is not installed."
  (let [?ft (vim.filetype.match {:filename filepath})
        ?lang (and ?ft (vim.treesitter.language.get_lang ?ft))]
    (if (and ?lang (pcall vim.treesitter.language.inspect ?lang))
        ?lang)))

(fn cached-lang [cache filepath]
  "Find the treesitter language of a file, and remember the answer, so that a
  file with several hunks resolves only once.

  Parameters:
    `cache`     The cache table. This is updated in place.
    `filepath`  The path of the file.

  Returns the name of the language, or nil if the file has no installed parser."
  (when (= nil (. cache filepath))
    ;; `false` records a miss, so that a second lookup does not resolve again.
    ;; Callers see nil, so that a miss reads the same as any other absent value.
    (set (. cache filepath) (or (resolve-lang filepath) false)))
  (let [cached (. cache filepath)]
    (if cached cached)))

(fn apply-capture [buf lines hl-group node]
  "Color the text of one treesitter capture.

  Parameters:
    `buf`       The buffer number.
    `lines`     The lines that were parsed. See `side-lines`.
    `hl-group`  The name of the highlight group of the capture.
    `node`      The captured treesitter node."
  (let [(start-row start-col end-row end-col) (node:range)]
    (for [row start-row end-row]
      (case (. lines (+ row 1))
        line (when line.paint?
               (let [from (if (= row start-row) start-col 0)
                     to (if (= row end-row) end-col (length line.text))]
                 (set-extmark buf line.row (+ from line.col)
                              {:end_col (+ to line.col)
                               :hl_group hl-group
                               :priority priority-syntax})))))))

(fn apply-tree-captures [buf lines source tree ltree]
  "Color the text of every highlight capture of one syntax tree.

  Parameters:
    `buf`     The buffer number.
    `lines`   The lines that were parsed. See `side-lines`.
    `source`  The parsed source string.
    `tree`    The syntax tree.
    `ltree`   The language tree that `tree` belongs to."
  (case (vim.treesitter.query.get (ltree:lang) :highlights)
    query (each [id node (query:iter_captures (tree:root) source)]
            (apply-capture buf lines (.. "@" (. query.captures id)) node))))

(fn apply-treesitter [buf lang lines]
  "Parse a run of lines, and color them with the highlight captures of one
  language.

  Parameters:
    `buf`    The buffer number.
    `lang`   The name of the treesitter language.
    `lines`  The lines to parse. See `side-lines`."
  (let [source (table.concat (icollect [_ line (ipairs lines)] line.text) "\n")
        parser (vim.treesitter.get_string_parser source lang)
        apply-to-tree (partial apply-tree-captures buf lines source)]
    ;; `true` parses the injected languages too, so that a fenced code block or
    ;; an embedded script gets the captures of its own language.
    (parser:parse true)
    (parser:for_each_tree apply-to-tree)))

(fn apply-side [buf lang-cache filepath lines]
  "Parse one side of a hunk body, and color it with the highlight captures of
  its language.

  Does nothing when the side holds no line, or when the file has no installed
  parser.

  Parameters:
    `buf`         The buffer number.
    `lang-cache`  The language cache. See `cached-lang`.
    `filepath`    The path of the file that the side belongs to.
    `lines`       The lines of the side. See `side-lines`."
  ;; pcall because a parse can raise, and one bad hunk must not stop the rest of
  ;; the buffer.
  (when (< 0 (length lines))
    (case (cached-lang lang-cache filepath)
      lang (pcall apply-treesitter buf lang lines))))

(fn apply-region [buf buf-lines lang-cache region]
  "Apply the diff highlights of one region.

  Parameters:
    `buf`         The buffer number.
    `buf-lines`   All the lines of the buffer, 1-indexed.
    `lang-cache`  The language cache. See `cached-lang`.
    `region`      The region. See `scan.regions`."
  (let [lines (region-lines buf-lines region)]
    (when (< 0 (length lines))
      (apply-line-backgrounds buf region lines)
      (each [i series (ipairs region.series)]
        ;; Arbitrarily choose the first series to own context highlights
        (let [series-lines (series-lines lines series (= 1 i))]
          ;; The new side colors the context lines, because both sides hold them.
          (apply-side buf lang-cache region.old-path
                      (side-lines series-lines :delete false))
          (apply-side buf lang-cache region.new-path
                      (side-lines series-lines :add true)))))))

(fn apply-regions [buf buf-lines regions]
  "Apply the diff highlights of every region of a buffer.

  Parameters:
    `buf`        The buffer number.
    `buf-lines`  All the lines of the buffer, 1-indexed.
    `regions`    The sequential table of regions. See `scan.regions`."
  (let [lang-cache {}]
    (each [_ region (ipairs regions)]
      (apply-region buf buf-lines lang-cache region))))

(fn clear [buf]
  "Remove every highlight that the plugin put on a buffer.

  Parameters:
    `buf`  The buffer number."
  (vim.api.nvim_buf_clear_namespace buf ns 0 -1))

(fn too-large? [buf max-lines]
  "Test whether a buffer is too large to highlight.

  Parameters:
    `buf`        The buffer number.
    `max-lines`  The line limit. A value of 0 or less means no limit.

  Returns true if the buffer has more lines than the limit."
  (and (< 0 max-lines) (< max-lines (vim.api.nvim_buf_line_count buf))))

(fn buffer [buf]
  "Apply the diff highlights of a whole buffer again.

  A buffer over the `max_lines` limit is left with no highlights at all.

  Parameters:
    `buf`  The buffer number."
  ;; Clear first and unconditionally, so that a buffer which grows past the
  ;; limit does not keep the highlights from when it was smaller.
  (clear buf)
  (let [opts (config.get)]
    (when (not (too-large? buf opts.max_lines))
      (let [filetype (vim.api.nvim_get_option_value :filetype {: buf})
            buf-lines (vim.api.nvim_buf_get_lines buf 0 -1 false)]
        (highlight.ensure)
        (apply-regions buf buf-lines (scan.regions buf-lines filetype))))))

{: clear : buffer}
