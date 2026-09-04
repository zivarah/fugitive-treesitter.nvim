-- [nfnl] fnl/fugitive-treesitter/scan.fnl
local _local_1_ = require("fugitive-treesitter.lib.str")
local char_at = _local_1_["char-at"]
local config = require("fugitive-treesitter.config")
local function body_prefix_3f(sigil)
  return (("+" == sigil) or ("-" == sigil) or (" " == sigil) or ("" == sigil))
end
local function line_kind(prefix)
  if prefix:find("+", 1, true) then
    return "add"
  elseif prefix:find("-", 1, true) then
    return "delete"
  else
    return "context"
  end
end
local function body_line_3f(_3fline)
  if _3fline then
    local sigil = char_at(_3fline, 1)
    return (body_prefix_3f(sigil) or ("\\" == sigil))
  else
    return false
  end
end
local function hunk_header_3f(_3fline)
  return ((nil ~= _3fline) and ("@" == char_at(_3fline, 1)))
end
local function body_row_3f(format, line)
  return body_line_3f(format["hunk-line"](line))
end
local function hunk_body_end(lines, start, format)
  local i = start
  while ((i <= #lines) and body_row_3f(format, lines[i])) do
    i = (i + 1)
  end
  return i
end
local function marker_width(header)
  return math.max((#header:match("^@+") - 1), 1)
end
local function hunk_region(lines, i, header, state, format)
  local start = (i + 1)
  local stop = hunk_body_end(lines, start, format)
  local width = marker_width(header)
  local _3fold_path = (state["old-path"] or state["new-path"])
  local _3fnew_path = (state["new-path"] or state["old-path"])
  local region
  if (_3fold_path and (stop > start)) then
    region = {first = (start - 1), last = (stop - 1), ["marker-width"] = width, ["text-col"] = (format["text-offset"] + width), series = format.series, ["series-width"] = format["series-width"], ["old-path"] = _3fold_path, ["new-path"] = _3fnew_path}
  else
    region = nil
  end
  return region, stop
end
local function header_path(line)
  local path = line:sub(5)
  if (path ~= "/dev/null") then
    return (path:match("^%a/(.+)$") or path)
  else
    return nil
  end
end
local function parse_git_file_header(line, state)
  if vim.startswith(line, "diff --git ") then
    return {}
  elseif vim.startswith(line, "--- ") then
    return vim.tbl_extend("force", state, {["old-path"] = header_path(line)})
  elseif vim.startswith(line, "+++ ") then
    return vim.tbl_extend("force", state, {["new-path"] = header_path(line)})
  else
    return nil
  end
end
local function parse_status_file_header(line, _state)
  local case_7_ = line:match("^[A-Z?] (.+)$")
  if (nil ~= case_7_) then
    local entry = case_7_
    local _3fold_path, _3fnew_path = entry:match("^(.-) %-> (.+)$")
    return {["old-path"] = (_3fold_path or entry), ["new-path"] = (_3fnew_path or entry)}
  else
    local _ = case_7_
    return nil
  end
end
local range_diff_pseudo_files = {Metadata = true, ["Commit message"] = true}
local function range_diff_header_pattern(old, operator, new)
  return ("^%s*()" .. old .. "()%s+()" .. operator .. "()%s+()" .. new .. "()")
end
local range_diff_header_patterns
do
  local commit_side = "%d+:%s+%x%x%x%x%x%x%x+"
  local missing_side = "%-+:%s+%-%-%-%-%-%-%-+"
  range_diff_header_patterns = {same = range_diff_header_pattern(commit_side, "=", commit_side), changed = range_diff_header_pattern(commit_side, "!", commit_side), dropped = range_diff_header_pattern(commit_side, "<", missing_side), added = range_diff_header_pattern(missing_side, ">", commit_side)}
end
local function match__3espan(from, to)
  return {col = (from - 1), ["end-col"] = (to - 1)}
end
local function range_diff_header_spans(line)
  local _3fspans = nil
  for kind, pattern in pairs(range_diff_header_patterns) do
    if _3fspans then break end
    local old_from,old_to,op_from,op_to,new_from,new_to = line:match(pattern)
    if old_from then
      _3fspans = {kind = kind, old = match__3espan(old_from, old_to), operator = match__3espan(op_from, op_to), new = match__3espan(new_from, new_to), subject = match__3espan(new_to, (1 + #line))}
    else
      _3fspans = nil
    end
  end
  return _3fspans
end
local function range_diff_patch_line(line)
  if vim.startswith(line, "    ") then
    local rest = string.sub(line, 5)
    if vim.startswith(rest, "@@") then
      return rest
    elseif body_prefix_3f(char_at(rest, 1)) then
      return string.sub(rest, 2)
    else
      return nil
    end
  else
    return nil
  end
end
local function range_diff_file_header_3f(patch_line)
  return (nil ~= patch_line:match("^[ +-]## .+ ##$"))
end
local function range_diff_hunk_line(line)
  local case_12_ = range_diff_patch_line(line)
  if (nil ~= case_12_) then
    local patch_line = case_12_
    if not range_diff_file_header_3f(patch_line) then
      return patch_line
    else
      return nil
    end
  else
    return nil
  end
end
local function range_diff_section_path(heading)
  return (string.gsub(string.gsub(heading, ":.*$", ""), "%s+%b()$", ""))
end
local function range_diff_section_state(heading)
  local path = range_diff_section_path(heading)
  if range_diff_pseudo_files[path] then
    return {}
  else
    return {["old-path"] = path, ["new-path"] = path}
  end
end
local function parse_range_diff_file_header(line, _state)
  local case_16_ = range_diff_patch_line(line)
  if (nil ~= case_16_) then
    local patch_line = case_16_
    local case_17_ = (patch_line:match("^[ +-]## (.+) ##$") or patch_line:match("^@@ (.+)$"))
    if (nil ~= case_17_) then
      local heading = case_17_
      return range_diff_section_state(heading)
    else
      return nil
    end
  else
    return nil
  end
end
local function range_diff_header_3f(line)
  return (nil ~= range_diff_header_spans(line))
end
local function colored(kind, range)
  return {col = range.col, ["end-col"] = range["end-col"], kind = kind}
end
local function whole_entry(spans)
  return {col = spans.old.col, ["end-col"] = spans.subject["end-col"]}
end
local function range_diff_header_decorations(line)
  local case_20_ = range_diff_header_spans(line)
  if (nil ~= case_20_) then
    local spans = case_20_
    local case_21_ = spans.kind
    if (case_21_ == "changed") then
      return {colored("commit-delete", spans.old), colored("commit", spans.operator), colored("commit-add", spans.new)}
    elseif (case_21_ == "dropped") then
      return {colored("commit-delete", whole_entry(spans))}
    elseif (case_21_ == "added") then
      return {colored("commit-add", whole_entry(spans))}
    elseif (case_21_ == "same") then
      return {colored("commit", whole_entry(spans))}
    else
      return nil
    end
  else
    return nil
  end
end
local function hunk_header_decorations(line, pattern, kind)
  local case_24_, case_25_, case_26_, case_27_ = line:match(pattern)
  if ((nil ~= case_24_) and (nil ~= case_25_) and (nil ~= case_26_) and (nil ~= case_27_)) then
    local marker_from = case_24_
    local marker_to = case_25_
    local heading_from = case_26_
    local heading = case_27_
    local marker = colored(kind, match__3espan(marker_from, marker_to))
    local path = range_diff_section_path(heading)
    if (0 < #path) then
      return {marker, colored("file", match__3espan(heading_from, (heading_from + #path)))}
    else
      return {marker}
    end
  else
    return nil
  end
end
local function section_heading_decorations(line)
  local case_30_, case_31_ = line:match("^    [ +-][ +-]## ()(.+) ##$")
  if ((nil ~= case_30_) and (nil ~= case_31_)) then
    local from = case_30_
    local heading = case_31_
    local path = range_diff_section_path(heading)
    local span = match__3espan(from, (from + #path))
    return {colored("file", span)}
  else
    return nil
  end
end
local function series_marker_decorations(line)
  local case_33_, case_34_ = line:match("^    ()[ +-]()")
  if ((nil ~= case_33_) and (nil ~= case_34_)) then
    local from = case_33_
    local to = case_34_
    local case_35_ = line_kind(char_at(line, from))
    if (case_35_ == "add") then
      return {colored("series-add", match__3espan(from, to))}
    elseif (case_35_ == "delete") then
      return {colored("series-delete", match__3espan(from, to))}
    else
      local _ = case_35_
      return {}
    end
  else
    local _ = case_33_
    return {}
  end
end
local function range_diff_patch_decorations(line)
  return vim.list_extend(series_marker_decorations(line), (hunk_header_decorations(line, "^    [ +-]()@@()%s*()(.*)$", "patch-hunk") or section_heading_decorations(line) or {}))
end
local function range_diff_decorations(line)
  return (range_diff_header_decorations(line) or hunk_header_decorations(line, "^    ()@@()%s*()(.*)$", "hunk") or range_diff_patch_decorations(line))
end
local function first_content_line(lines)
  local _3ffound = nil
  for _, line in ipairs(lines) do
    if _3ffound then break end
    if ("" ~= vim.trim(line)) then
      _3ffound = line
    else
      _3ffound = nil
    end
  end
  return _3ffound
end
local function range_diff_3f(lines)
  local case_39_ = first_content_line(lines)
  if (nil ~= case_39_) then
    local line = case_39_
    return range_diff_header_3f(line)
  else
    local _ = case_39_
    return false
  end
end
local function unwrapped_hunk_line(line)
  return line
end
local formats = {git = {["hunk-line"] = unwrapped_hunk_line, ["parse-file-header"] = parse_git_file_header, ["text-offset"] = 0, series = {"context"}, ["series-width"] = 0}, fugitive = {["hunk-line"] = unwrapped_hunk_line, ["parse-file-header"] = parse_status_file_header, ["text-offset"] = 0, series = {"context"}, ["series-width"] = 0}, ["range-diff"] = {["hunk-line"] = range_diff_hunk_line, ["parse-file-header"] = parse_range_diff_file_header, ["text-offset"] = 5, series = {"delete", "add"}, ["series-width"] = 1, decorate = range_diff_decorations}}
local function buffer_format(lines, filetype)
  local opts = config.get()
  if (filetype == "fugitive") then
    return formats.fugitive
  elseif (filetype == "git") then
    if (opts.range_diff.enabled and range_diff_3f(lines)) then
      return formats["range-diff"]
    else
      return formats.git
    end
  else
    return nil
  end
end
local function scan(lines, format)
  local regions = {}
  local state = {}
  local i = 1
  while (i <= #lines) do
    local line = lines[i]
    local _3fhunk_line = format["hunk-line"](line)
    local _3fnew_state = format["parse-file-header"](line, state)
    if _3fnew_state then
      state = _3fnew_state
    else
    end
    if hunk_header_3f(_3fhunk_line) then
      local region, stop = hunk_region(lines, i, _3fhunk_line, state, format)
      if region then
        table.insert(regions, region)
      else
      end
      i = stop
    else
      i = (i + 1)
    end
  end
  return regions
end
local function regions(lines, filetype)
  local format = buffer_format(lines, filetype)
  if format then
    return scan(lines, format)
  else
    return {}
  end
end
local function decorations(lines, filetype)
  local format = buffer_format(lines, filetype)
  local spans = {}
  local _48_
  do
    local t_47_ = format
    if (nil ~= t_47_) then
      t_47_ = t_47_.decorate
    else
    end
    _48_ = t_47_
  end
  if _48_ then
    for i, line in ipairs(lines) do
      for _, span in ipairs(format.decorate(line)) do
        span.row = (i - 1)
        table.insert(spans, span)
      end
    end
  else
  end
  return spans
end
return {["body-prefix?"] = body_prefix_3f, ["line-kind"] = line_kind, ["range-diff?"] = range_diff_3f, regions = regions, decorations = decorations}
