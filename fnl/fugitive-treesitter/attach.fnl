;;; Keeping the highlights of a buffer up to date.
;;;
;;; A `git`-format diff buffer does not change after it loads, so it is
;;; highlighted once. The fugitive status buffer is rewritten every time a hunk
;;; is expanded or collapsed, so it needs a listener.

(local render (require :fugitive-treesitter.render))
(local highlight (require :fugitive-treesitter.highlight))

(local augroup :fugitive-treesitter)

;; Buffer-local, so that a reload under the same buffer number can tell its own
;; listener apart from one left over from an earlier load.
(local generation-key :fugitive_treesitter_generation)

(fn next-generation [buf]
  "Start a new highlight generation for a buffer.

  Parameters:
    `buf`  The buffer number.

  Returns the token of the new generation."
  (let [generation (+ 1 (or (. vim.b buf generation-key) 0))]
    (set (. vim.b buf generation-key) generation)
    generation))

(fn stale? [buf generation]
  "Test whether a listener belongs to an earlier load of a buffer.

  Parameters:
    `buf`         The buffer number.
    `generation`  The token that the listener was attached with.

  Returns true if the buffer is gone, or if a later generation superseded this
  one."
  (or (not (vim.api.nvim_buf_is_valid buf))
      (not= generation (. vim.b buf generation-key))))

(fn de-spam [f]
  "Wrap a function that needs to run under `vim.schedule`, returning a function
  that will de-duplicate repeated calls until the function has actually run.

  Parameters:
    `f`  The function to wrap.

  Returns the wrapper, which takes no arguments."
  (var scheduled? false)
  #(when (not scheduled?)
     (set scheduled? true)
     (vim.schedule (fn []
                     (set scheduled? false)
                     (f)))))

(fn refresh [?buf]
  "Apply the diff highlights of a buffer again.

  Parameters:
    `?buf`  The buffer number. Defaults to the current buffer."
  (let [buf (or ?buf (vim.api.nvim_get_current_buf))]
    (render.buffer buf)))

(fn attach-diff [buf]
  "Highlight a `git`-format diff buffer once.

  Parameters:
    `buf`  The buffer number."
  (vim.schedule #(when (vim.api.nvim_buf_is_valid buf)
                   (refresh buf))))

(fn attach-status [buf]
  "Highlight a fugitive status buffer, and highlight it again after every
  change, so that expanding or collapsing a hunk refreshes the overlay.

  Parameters:
    `buf`  The buffer number."
  (let [generation (next-generation buf)
        rehighlight (de-spam #(when (vim.api.nvim_buf_is_valid buf)
                                (refresh buf)))]
    (fn on-lines []
      (let [stale (stale? buf generation)]
        (when (not stale)
          (rehighlight))
        ;; A truthy return detaches the listener.
        stale))

    ;; Attach before the first highlight, so that a failure of the highlight
    ;; cannot leave the buffer without a listener.
    (vim.api.nvim_buf_attach buf false {:on_lines on-lines})
    (rehighlight)))

;; The filetypes that the plugin highlights, and the function that starts
;; highlighting a buffer of each one.
(local attachers {:git attach-diff :fugitive attach-status})

(fn attach [buf]
  "Start highlighting a buffer, in the way that its filetype needs.

  Does nothing for a buffer of any other filetype.

  Parameters:
    `buf`  The buffer number."
  (case (. attachers (vim.api.nvim_get_option_value :filetype {: buf}))
    attacher (attacher buf)))

(fn attach-loaded []
  "Start highlighting every buffer that is loaded now.

  Reattaching to a buffer that already has a listener is safe, because the new
  listener retires the old one."
  (each [_ buf (ipairs (vim.api.nvim_list_bufs))]
    (when (vim.api.nvim_buf_is_loaded buf)
      (attach buf))))

(fn enable []
  "Start highlighting fugitive diffs, including in already-loaded buffers."
  (let [group (vim.api.nvim_create_augroup augroup {:clear true})]
    (vim.api.nvim_create_autocmd :FileType
                                 {: group
                                  :pattern (vim.tbl_keys attachers)
                                  :callback (fn [ev] (attach ev.buf))})
    (vim.api.nvim_create_autocmd :ColorScheme
                                 {: group :callback highlight.invalidate}))
  (attach-loaded))

(fn disable []
  "Stop highlighting fugitive diffs, and remove the highlights that are already
  on screen."
  (pcall vim.api.nvim_del_augroup_by_name augroup)
  (each [_ buf (ipairs (vim.api.nvim_list_bufs))]
    (when (vim.api.nvim_buf_is_loaded buf)
      (render.clear buf))))

{: refresh : enable : disable}
