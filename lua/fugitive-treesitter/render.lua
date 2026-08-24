-- [nfnl] fnl/fugitive-treesitter/render.fnl
local _local_1_ = require("fugitive-treesitter.lib.str")
local char_at = _local_1_["char-at"]
local highlight = require("fugitive-treesitter.highlight")
local scan = require("fugitive-treesitter.scan")
local ns = vim.api.nvim_create_namespace("fugitive-treesitter")
local priority_line = 190
local priority_syntax = 210
local function set_extmark(buf, row, col, opts)
  return pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, col, vim.tbl_extend("force", opts, {strict = false}))
end
local function region_lines(buf_lines, region)
  local tbl_26_ = {}
  local i_27_ = 0
  for row = region.first, (region.last - 1) do
    local val_28_
    do
      local _3fline = buf_lines[(row + 1)]
      local _3fprefix = (_3fline and char_at(_3fline, 1))
      if (_3fprefix and scan["body-prefix?"](_3fprefix)) then
        val_28_ = {row = row, prefix = _3fprefix, text = string.sub(_3fline, 2)}
      else
        val_28_ = nil
      end
    end
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
local function side_lines(lines, prefix, paint_context_3f)
  local tbl_26_ = {}
  local i_27_ = 0
  for _, line in ipairs(lines) do
    local val_28_
    do
      local case_4_ = line.prefix
      if (case_4_ == prefix) then
        val_28_ = {row = line.row, text = line.text, ["paint?"] = true}
      elseif (case_4_ == " ") then
        val_28_ = {row = line.row, text = line.text, ["paint?"] = paint_context_3f}
      else
        val_28_ = nil
      end
    end
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
local function prefix__3ehl_group(prefix)
  if (prefix == "+") then
    return highlight["add-group"]
  elseif (prefix == "-") then
    return highlight["delete-group"]
  else
    return nil
  end
end
local function apply_line_backgrounds(buf, lines)
  for _, _8_ in ipairs(lines) do
    local row = _8_.row
    local prefix = _8_.prefix
    local case_9_ = prefix__3ehl_group(prefix)
    if (nil ~= case_9_) then
      local hl_group = case_9_
      set_extmark(buf, row, 0, {end_row = (row + 1), end_col = 0, hl_group = hl_group, hl_eol = true, priority = priority_line})
    else
    end
  end
  return nil
end
local function resolve_lang(filepath)
  local _3fft = vim.filetype.match({filename = filepath})
  local _3flang = (_3fft and vim.treesitter.language.get_lang(_3fft))
  if (_3flang and pcall(vim.treesitter.language.inspect, _3flang)) then
    return _3flang
  else
    return nil
  end
end
local function cached_lang(cache, filepath)
  if (nil == cache[filepath]) then
    cache[filepath] = (resolve_lang(filepath) or false)
  else
  end
  local cached = cache[filepath]
  if cached then
    return cached
  else
    return nil
  end
end
local function apply_capture(buf, lines, hl_group, node)
  local start_row, start_col, end_row, end_col = node:range()
  for row = start_row, end_row do
    local case_14_ = lines[(row + 1)]
    if (nil ~= case_14_) then
      local line = case_14_
      if line["paint?"] then
        local from
        if (row == start_row) then
          from = start_col
        else
          from = 0
        end
        local to
        if (row == end_row) then
          to = end_col
        else
          to = #line.text
        end
        set_extmark(buf, line.row, (from + 1), {end_col = (to + 1), hl_group = hl_group, priority = priority_syntax})
      else
      end
    else
    end
  end
  return nil
end
local function apply_tree_captures(buf, lines, source, tree, ltree)
  local case_19_ = vim.treesitter.query.get(ltree:lang(), "highlights")
  if (nil ~= case_19_) then
    local query = case_19_
    for id, node in query:iter_captures(tree:root(), source) do
      apply_capture(buf, lines, ("@" .. query.captures[id]), node)
    end
    return nil
  else
    return nil
  end
end
local function apply_treesitter(buf, lang, lines)
  local source
  local _21_
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, line in ipairs(lines) do
      local val_28_ = line.text
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    _21_ = tbl_26_
  end
  source = table.concat(_21_, "\n")
  local parser = vim.treesitter.get_string_parser(source, lang)
  local apply_to_tree
  local function _23_(...)
    return apply_tree_captures(buf, lines, source, ...)
  end
  apply_to_tree = _23_
  parser:parse()
  return parser:for_each_tree(apply_to_tree)
end
local function apply_side(buf, lang_cache, filepath, lines)
  if (0 < #lines) then
    local case_24_ = cached_lang(lang_cache, filepath)
    if (nil ~= case_24_) then
      local lang = case_24_
      return pcall(apply_treesitter, buf, lang, lines)
    else
      return nil
    end
  else
    return nil
  end
end
local function apply_region(buf, buf_lines, lang_cache, region)
  local lines = region_lines(buf_lines, region)
  if (0 < #lines) then
    apply_line_backgrounds(buf, lines)
    apply_side(buf, lang_cache, region["old-path"], side_lines(lines, "-", false))
    return apply_side(buf, lang_cache, region["new-path"], side_lines(lines, "+", true))
  else
    return nil
  end
end
local function apply_regions(buf, buf_lines, regions)
  local lang_cache = {}
  for _, region in ipairs(regions) do
    apply_region(buf, buf_lines, lang_cache, region)
  end
  return nil
end
local function clear(buf)
  return vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end
local function buffer(buf)
  local filetype = vim.api.nvim_get_option_value("filetype", {buf = buf})
  local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  highlight.ensure()
  clear(buf)
  return apply_regions(buf, buf_lines, scan.regions(buf_lines, filetype))
end
return {clear = clear, buffer = buffer}
