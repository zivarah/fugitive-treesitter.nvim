-- [nfnl] fnl/fugitive-treesitter/scan.fnl
local _local_1_ = require("fugitive-treesitter.lib.str")
local char_at = _local_1_["char-at"]
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
local function unwrapped_hunk_line(line)
  return line
end
local formats = {git = {["hunk-line"] = unwrapped_hunk_line, ["parse-file-header"] = parse_git_file_header, ["text-offset"] = 0, series = {"context"}, ["series-width"] = 0}, fugitive = {["hunk-line"] = unwrapped_hunk_line, ["parse-file-header"] = parse_status_file_header, ["text-offset"] = 0, series = {"context"}, ["series-width"] = 0}}
local function scan(lines, format)
  local regions = {}
  local state = {}
  local i = 1
  while (i <= #lines) do
    local line = lines[i]
    local _3fhunk_line = format["hunk-line"](line)
    if hunk_header_3f(_3fhunk_line) then
      local region, stop = hunk_region(lines, i, _3fhunk_line, state, format)
      if region then
        table.insert(regions, region)
      else
      end
      i = stop
    else
      local _3fnew_state = format["parse-file-header"](line, state)
      if _3fnew_state then
        state = _3fnew_state
      else
      end
      i = (i + 1)
    end
  end
  return regions
end
local function regions(lines, filetype)
  local function _12_()
    if ("fugitive" == filetype) then
      return formats.fugitive
    else
      return formats.git
    end
  end
  return scan(lines, _12_())
end
return {["body-prefix?"] = body_prefix_3f, ["line-kind"] = line_kind, regions = regions}
