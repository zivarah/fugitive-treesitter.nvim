;;; Syntax folds for Git range-diff output.

(when (not vim.b.current_syntax)
  (set vim.b.current_syntax :rangediff)
  ;; `:syntax` is an Ex command with no native Lua equivalent. Each region is
  ;; transparent, so a hunk fold can sit inside a commit fold without changing
  ;; the highlights inside either region.
  (vim.cmd "
    let s:header_pattern = '\\v^\\s*(-+|\\d+):\\s+(-{7,}|\\x{7,})\\s+[<=>!]\\s+(-+|\\d+):\\s+(-{7,}|\\x{7,})(\\s+.*)?$'

    exe 'syn region rangediffOneCommit'
        \\ . ' start=/' . s:header_pattern . '/'
        \\ . ' skip=/\\v^   [ @+-]/'
        \\ . ' end=/\\(' . s:header_pattern . '\\m\\)\\@=/'
        \\ . ' fold'
        \\ . ' transparent'

    exe 'syn region rangediffOneHunk'
        \\ . ' start=/^    @@/'
        \\ . ' skip=/\\v^    [ -+]/'
        \\ . ' end=/\\(^    @@\\)\\@=/'
        \\ . ' end=/\\(' . s:header_pattern . '\\m\\)\\@=/'
        \\ . ' fold'
        \\ . ' transparent'
  "))
