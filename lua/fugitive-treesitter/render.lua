-- [nfnl] fnl/fugitive-treesitter/render.fnl
local _local_1_ = require("fugitive-treesitter.lib.str")
local char_at = _local_1_["char-at"]
local config = require("fugitive-treesitter.config")
local highlight = require("fugitive-treesitter.highlight")
local scan = require("fugitive-treesitter.scan")
local ns = vim.api.nvim_create_namespace("fugitive-treesitter")
local priority_line = 190
local priority_syntax = 210
local function set_extmark(buf, row, col, opts)
  return pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, col, vim.tbl_extend("force", opts, {strict = false}))
end
local function marker_3f(marker)
  local body_3f = true
  for i = 1, #marker do
    if not body_3f then break end
    body_3f = scan["body-prefix?"](char_at(marker, i))
  end
  return body_3f
end
local function region_columns(region)
  local text = region["text-col"]
  local marker = (text - region["marker-width"])
  local series = (marker - region["series-width"])
  return {series = series, marker = marker, text = text}
end
local function region_lines(buf_lines, region)
  local cols = region_columns(region)
  local tbl_26_ = {}
  local i_27_ = 0
  for row = region.first, (region.last - 1) do
    local val_28_
    do
      local case_2_ = buf_lines[(row + 1)]
      if (nil ~= case_2_) then
        local line = case_2_
        local marker = string.sub(line, (cols.marker + 1), cols.text)
        local series = string.sub(line, (cols.series + 1), cols.marker)
        local text = string.sub(line, (cols.text + 1))
        if marker_3f(marker) then
          val_28_ = {row = row, col = cols.text, series = scan["line-kind"](series), kind = scan["line-kind"](marker), text = text}
        else
          val_28_ = nil
        end
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
local function series_lines(lines, series, context_owner_3f)
  local tbl_26_ = {}
  local i_27_ = 0
  for _, line in ipairs(lines) do
    local val_28_
    do
      local shared_3f = ("context" == line.series)
      if (shared_3f or (series == line.series)) then
        val_28_ = {row = line.row, col = line.col, kind = line.kind, text = line.text, ["owned?"] = (not shared_3f or context_owner_3f)}
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
local function side_lines(lines, kind, paint_context_3f)
  local tbl_26_ = {}
  local i_27_ = 0
  for _, line in ipairs(lines) do
    local val_28_
    do
      local case_8_ = line.kind
      if (case_8_ == kind) then
        val_28_ = {row = line.row, col = line.col, text = line.text, ["paint?"] = line["owned?"]}
      elseif (case_8_ == "context") then
        val_28_ = {row = line.row, col = line.col, text = line.text, ["paint?"] = (paint_context_3f and line["owned?"])}
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
local function line_hl_group(kind, series)
  local dim_3f = ("delete" == series)
  if (kind == "add") then
    if dim_3f then
      return highlight["add-dim-group"]
    else
      return highlight["add-group"]
    end
  elseif (kind == "delete") then
    if dim_3f then
      return highlight["delete-dim-group"]
    else
      return highlight["delete-group"]
    end
  else
    return nil
  end
end
local function apply_line_backgrounds(buf, region, lines)
  local cols = region_columns(region)
  for _, _14_ in ipairs(lines) do
    local row = _14_.row
    local kind = _14_.kind
    local series = _14_.series
    local col = _14_.col
    local text = _14_.text
    local case_15_ = line_hl_group(kind, series)
    if (nil ~= case_15_) then
      local hl_group = case_15_
      set_extmark(buf, row, cols.marker, {end_col = (col + #text), hl_group = hl_group, priority = priority_line})
    else
    end
  end
  return nil
end
local decoration_groups = {["series-add"] = highlight["add-group"], ["series-delete"] = highlight["delete-group"], commit = highlight["commit-group"], ["commit-add"] = highlight["commit-add-group"], ["commit-delete"] = highlight["commit-delete-group"], hunk = highlight["hunk-group"], ["patch-hunk"] = highlight["patch-hunk-group"], file = highlight["file-group"]}
local function apply_decorations(buf, parts)
  for _, part in ipairs(parts) do
    local case_17_ = decoration_groups[part.kind]
    if (nil ~= case_17_) then
      local hl_group = case_17_
      set_extmark(buf, part.row, part.col, {end_col = part["end-col"], hl_group = hl_group, priority = priority_syntax})
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
    local case_22_ = lines[(row + 1)]
    if (nil ~= case_22_) then
      local line = case_22_
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
        set_extmark(buf, line.row, (from + line.col), {end_col = (to + line.col), hl_group = hl_group, priority = priority_syntax})
      else
      end
    else
    end
  end
  return nil
end
local function apply_tree_captures(buf, lines, source, tree, ltree)
  local case_27_ = vim.treesitter.query.get(ltree:lang(), "highlights")
  if (nil ~= case_27_) then
    local query = case_27_
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
  local _29_
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
    _29_ = tbl_26_
  end
  source = table.concat(_29_, "\n")
  local parser = vim.treesitter.get_string_parser(source, lang)
  local apply_to_tree
  local function _31_(...)
    return apply_tree_captures(buf, lines, source, ...)
  end
  apply_to_tree = _31_
  parser:parse(true)
  return parser:for_each_tree(apply_to_tree)
end
local function apply_side(buf, lang_cache, filepath, lines)
  if (0 < #lines) then
    local case_32_ = cached_lang(lang_cache, filepath)
    if (nil ~= case_32_) then
      local lang = case_32_
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
    apply_line_backgrounds(buf, region, lines)
    for i, series in ipairs(region.series) do
      local series_lines0 = series_lines(lines, series, (1 == i))
      apply_side(buf, lang_cache, region["old-path"], side_lines(series_lines0, "delete", false))
      apply_side(buf, lang_cache, region["new-path"], side_lines(series_lines0, "add", true))
    end
    return nil
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
local function too_large_3f(buf, max_lines)
  return ((0 < max_lines) and (max_lines < vim.api.nvim_buf_line_count(buf)))
end
local function buffer(buf)
  clear(buf)
  local opts = config.get()
  if not too_large_3f(buf, opts.max_lines) then
    local filetype = vim.api.nvim_get_option_value("filetype", {buf = buf})
    local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    highlight.ensure()
    apply_decorations(buf, scan.decorations(buf_lines, filetype))
    return apply_regions(buf, buf_lines, scan.regions(buf_lines, filetype))
  else
    return nil
  end
end
return {clear = clear, buffer = buffer}
