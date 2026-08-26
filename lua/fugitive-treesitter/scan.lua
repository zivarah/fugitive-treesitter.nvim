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
  local case_11_ = range_diff_patch_line(line)
  if (nil ~= case_11_) then
    local patch_line = case_11_
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
  local case_15_ = range_diff_patch_line(line)
  if (nil ~= case_15_) then
    local patch_line = case_15_
    local case_16_ = (patch_line:match("^[ +-]## (.+) ##$") or patch_line:match("^@@ (.+)$"))
    if (nil ~= case_16_) then
      local heading = case_16_
      return range_diff_section_state(heading)
    else
      return nil
    end
  else
    return nil
  end
end
local function range_diff_header_3f(line)
  local found_3f = false
  for _, pattern in pairs(range_diff_header_patterns) do
    if found_3f then break end
    found_3f = (nil ~= line:match(pattern))
  end
  return found_3f
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
  local case_20_ = first_content_line(lines)
  if (nil ~= case_20_) then
    local line = case_20_
    return range_diff_header_3f(line)
  else
    local _ = case_20_
    return false
  end
end
local function unwrapped_hunk_line(line)
  return line
end
local formats = {git = {["hunk-line"] = unwrapped_hunk_line, ["parse-file-header"] = parse_git_file_header, ["text-offset"] = 0, series = {"context"}, ["series-width"] = 0}, fugitive = {["hunk-line"] = unwrapped_hunk_line, ["parse-file-header"] = parse_status_file_header, ["text-offset"] = 0, series = {"context"}, ["series-width"] = 0}, ["range-diff"] = {["hunk-line"] = range_diff_hunk_line, ["parse-file-header"] = parse_range_diff_file_header, ["text-offset"] = 5, series = {"delete", "add"}, ["series-width"] = 1}}
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
  return scan(lines, buffer_format(lines, filetype))
end
return {["body-prefix?"] = body_prefix_3f, ["line-kind"] = line_kind, regions = regions}
