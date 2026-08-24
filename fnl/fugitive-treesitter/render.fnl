;;; Putting the diff highlights on a buffer as extmarks.
;;;
;;; The hunk body is parsed without its diff markers, so every column that
;;; comes back from treesitter is one to the left of where it belongs in the
;;; buffer. Each extmark shifts back by one to compensate.

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

(fn region-lines [buf-lines region]
  "Collect the hunk body lines of a region.

  Parameters:
    `buf-lines`  All the lines of the buffer, 1-indexed.
    `region`     The region. See `scan.regions`.

  Returns a sequential table of `{:row :kind :text}`. `row` is the 0-based
  buffer row, `kind` is the line kind (see `scan.line-kind`), and `text` is the
  line without its marker. A line that is not part of a hunk body is left out."
  (fcollect [row region.first (- region.last 1)]
    (let [?line (. buf-lines (+ row 1))
          ?prefix (and ?line (char-at ?line 1))]
      (if (and ?prefix (scan.body-prefix? ?prefix))
          {: row :kind (scan.line-kind ?prefix) :text (string.sub ?line 2)}))))

(fn side-lines [lines kind paint-context?]
  "Reconstruct one side of a hunk body.

  A side holds its own changed lines together with every context line, so that
  the text reads as the file did on that side of the change. The two sides share
  their context lines, so only one of them colors those.

  Parameters:
    `lines`           The hunk body lines. See `region-lines`.
    `kind`            The kind of the changed lines of the side, `:add` or
                      `:delete`. See `scan.line-kind`.
    `paint-context?`  Whether this side colors its context lines.

  Returns a sequential table of `{:row :text :paint?}`, in buffer order. A line
  with a false `paint?` is present only to give the parser its surrounding
  code."
  (icollect [_ line (ipairs lines)]
    (match line.kind
      kind {:row line.row :text line.text :paint? true}
      :context {:row line.row :text line.text :paint? paint-context?})))

(fn kind->hl-group [kind]
  "Get the highlight group that colors a whole diff line.

  Parameters:
    `kind`  The line kind. See `scan.line-kind`.

  Returns the name of the group, or nil for a context line."
  (case kind
    :add highlight.add-group
    :delete highlight.delete-group))

(fn apply-line-backgrounds [buf lines]
  "Color the whole of each added and each removed line.

  The background reaches past the end of the text with `hl_eol` rather than
  with a `line_hl_group`, so that a later highlight can still draw over it.

  Parameters:
    `buf`    The buffer number.
    `lines`  The hunk body lines. See `region-lines`."
  (each [_ {: row : kind} (ipairs lines)]
    (case (kind->hl-group kind)
      hl-group (set-extmark buf row 0
                            {:end_row (+ row 1)
                             :end_col 0
                             :hl_group hl-group
                             :hl_eol true
                             :priority priority-line}))))

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
                 (set-extmark buf line.row (+ from 1)
                              {:end_col (+ to 1)
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
      (apply-line-backgrounds buf lines)
      ;; The new side colors the context lines, because both sides hold them.
      (apply-side buf lang-cache region.old-path
                  (side-lines lines :delete false))
      (apply-side buf lang-cache region.new-path (side-lines lines :add true)))))

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
