-- [nfnl] syntax/rangediff.fnl
if not vim.b.current_syntax then
  vim.b.current_syntax = "rangediff"
  return vim.cmd("\n    let s:header_pattern = '\\v^\\s*(-+|\\d+):\\s+(-{7,}|\\x{7,})\\s+[<=>!]\\s+(-+|\\d+):\\s+(-{7,}|\\x{7,})(\\s+.*)?$'\n\n    exe 'syn region rangediffOneCommit'\n        \\ . ' start=/' . s:header_pattern . '/'\n        \\ . ' skip=/\\v^   [ @+-]/'\n        \\ . ' end=/\\(' . s:header_pattern . '\\m\\)\\@=/'\n        \\ . ' fold'\n        \\ . ' transparent'\n\n    exe 'syn region rangediffOneHunk'\n        \\ . ' start=/^    @@/'\n        \\ . ' skip=/\\v^    [ -+]/'\n        \\ . ' end=/\\(^    @@\\)\\@=/'\n        \\ . ' end=/\\(' . s:header_pattern . '\\m\\)\\@=/'\n        \\ . ' fold'\n        \\ . ' transparent'\n  ")
else
  return nil
end
