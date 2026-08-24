-- [nfnl] fnl/fugitive-treesitter/scan.fnl
local _local_1_ = require("fugitive-treesitter.lib.str")
local char_at = _local_1_["char-at"]
local function body_prefix_3f(sigil)
  return (("+" == sigil) or ("-" == sigil) or (" " == sigil) or ("" == sigil))
end
local function line_kind(prefix)
  if ("+" == prefix) then
    return "add"
  elseif ("-" == prefix) then
    return "delete"
  else
    return "context"
  end
end
local function body_line_3f(line)
  local sigil = char_at(line, 1)
  return (body_prefix_3f(sigil) or ("\\" == sigil))
end
local function hunk_header_3f(line)
  return ("@" == char_at(line, 1))
end
local function hunk_body_end(lines, start)
  local i = start
  while ((i <= #lines) and body_line_3f(lines[i])) do
    i = (i + 1)
  end
  return i
end
local function hunk_region(lines, i, state)
  local start = (i + 1)
  local stop = hunk_body_end(lines, start)
  local _3fold_path = (state["old-path"] or state["new-path"])
  local _3fnew_path = (state["new-path"] or state["old-path"])
  local region
  if (_3fold_path and (stop > start)) then
    region = {first = (start - 1), last = (stop - 1), ["old-path"] = _3fold_path, ["new-path"] = _3fnew_path}
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
local function git_file_state(line, state)
  if vim.startswith(line, "diff --git ") then
    return {}
  elseif vim.startswith(line, "--- ") then
    return vim.tbl_extend("force", state, {["old-path"] = header_path(line)})
  elseif vim.startswith(line, "+++ ") then
    return vim.tbl_extend("force", state, {["new-path"] = header_path(line)})
  else
    return state
  end
end
local function status_file_state(line, state)
  local case_6_ = line:match("^[A-Z?] (.+)$")
  if (nil ~= case_6_) then
    local entry = case_6_
    local _3fold_path, _3fnew_path = entry:match("^(.-) %-> (.+)$")
    return {["old-path"] = (_3fold_path or entry), ["new-path"] = (_3fnew_path or entry)}
  else
    local _ = case_6_
    return state
  end
end
local function scan(lines, track)
  local regions = {}
  local state = {}
  local i = 1
  while (i <= #lines) do
    local line = lines[i]
    if hunk_header_3f(line) then
      local region, stop = hunk_region(lines, i, state)
      if region then
        table.insert(regions, region)
      else
      end
      i = stop
    else
      state = track(line, state)
      i = (i + 1)
    end
  end
  return regions
end
local function regions(lines, filetype)
  local function _10_()
    if ("fugitive" == filetype) then
      return status_file_state
    else
      return git_file_state
    end
  end
  return scan(lines, _10_())
end
return {["body-prefix?"] = body_prefix_3f, ["line-kind"] = line_kind, regions = regions}
