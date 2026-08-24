-- [nfnl] fnl/fugitive-treesitter/lib/str.fnl
local function char_at(s, i)
  return string.sub(s, i, i)
end
return {["char-at"] = char_at}
