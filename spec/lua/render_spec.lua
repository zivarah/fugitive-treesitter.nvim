-- [nfnl] spec/fnl/render_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local assert = require("luassert.assert")
local render = require("fugitive-treesitter.render")
local highlight = require("fugitive-treesitter.highlight")
local ns = vim.api.nvim_get_namespaces()["fugitive-treesitter"]
local priority_line = 190
local function diff_buffer(filetype, lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", filetype, {buf = buf})
  return buf
end
local function marks(buf)
  local tbl_26_ = {}
  local i_27_ = 0
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {details = true})) do
    local val_28_
    do
      local _0 = mark[1]
      local row = mark[2]
      local col = mark[3]
      local details = mark[4]
      val_28_ = {row = row, col = col, ["end-col"] = details.end_col, ["hl-group"] = details.hl_group, ["hl-eol"] = details.hl_eol, ["line-hl-group"] = details.line_hl_group, priority = details.priority}
    end
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
local function capture_3f(mark)
  return (mark["hl-group"] and vim.startswith(mark["hl-group"], "@"))
end
local function background_3f(mark)
  return (priority_line == mark.priority)
end
local function background_on(buf, row)
  local _3ffound = nil
  for _, mark in ipairs(marks(buf)) do
    if ((row == mark.row) and background_3f(mark)) then
      _3ffound = mark
    else
      _3ffound = _3ffound
    end
  end
  return _3ffound
end
local function line_groups(buf)
  local tbl_21_ = {}
  for _, mark in ipairs(marks(buf)) do
    local k_22_, v_23_
    if background_3f(mark) then
      k_22_, v_23_ = mark.row, mark["hl-group"]
    else
      k_22_, v_23_ = nil
    end
    if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
      tbl_21_[k_22_] = v_23_
    else
    end
  end
  return tbl_21_
end
local function captures_on(buf, row)
  local lines = vim.api.nvim_buf_get_lines(buf, row, (row + 1), false)
  local line = lines[1]
  local tbl_21_ = {}
  for _, mark in ipairs(marks(buf)) do
    local k_22_, v_23_
    if ((row == mark.row) and capture_3f(mark)) then
      k_22_, v_23_ = string.sub(line, (mark.col + 1), mark["end-col"]), mark["hl-group"]
    else
      k_22_, v_23_ = nil
    end
    if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
      tbl_21_[k_22_] = v_23_
    else
    end
  end
  return tbl_21_
end
local function duplicate_captures_on(buf, row)
  local seen = {}
  local duplicates = {}
  for _, mark in ipairs(marks(buf)) do
    if ((row == mark.row) and mark["hl-group"] and vim.startswith(mark["hl-group"], "@")) then
      local key = string.format("%d:%d:%s", mark.col, mark["end-col"], mark["hl-group"])
      if seen[key] then
        table.insert(duplicates, key)
      else
        seen[key] = true
      end
    else
    end
  end
  return duplicates
end
local one_file = {"diff --git a/a.lua b/a.lua", "--- a/a.lua", "+++ b/a.lua", "@@ -1,3 +1,3 @@", " local m = {}", "-local timeout = 30", "+local timeout = 60", " return m"}
local function _10_()
  local function _11_()
    local buf = diff_buffer("git", one_file)
    render.buffer(buf)
    return assert.same({[5] = highlight["delete-group"], [6] = highlight["add-group"]}, line_groups(buf))
  end
  it("colors added and removed lines but not context lines", _11_)
  local function _12_()
    local buf = diff_buffer("git", one_file)
    local removed = one_file[6]
    render.buffer(buf)
    for _, mark in ipairs(marks(buf)) do
      assert.is_nil(mark["line-hl-group"])
      assert.is_falsy(mark["hl-eol"])
    end
    local background = background_on(buf, 5)
    assert.equals(highlight["delete-group"], background["hl-group"])
    assert.equals(0, background.col)
    return assert.equals(#removed, background["end-col"])
  end
  it("ends the line background where the line ends", _12_)
  local function _13_()
    local buf = diff_buffer("git", {"diff --git a/a.lua b/a.lua", "--- a/a.lua", "+++ b/a.lua", "@@ -1,2 +1,3 @@", " local m = {}", "+", " return m"})
    render.buffer(buf)
    local background = background_on(buf, 5)
    assert.equals(highlight["add-group"], background["hl-group"])
    assert.equals(0, background.col)
    return assert.equals(1, background["end-col"])
  end
  it("colors a line that holds nothing but its marker", _13_)
  local function _14_()
    local buf = diff_buffer("git", one_file)
    render.buffer(buf)
    assert.equals("@number", captures_on(buf, 5)["30"])
    assert.equals("@number", captures_on(buf, 6)["60"])
    return assert.equals("@keyword", captures_on(buf, 5)["local"])
  end
  it("places treesitter captures shifted past the diff marker", _14_)
  local function _15_()
    local buf = diff_buffer("fugitive", {"Head: main", "Unstaged (1)", "M a.lua", "@@ -1,2 +1,2 @@", "-local timeout = 30", "+local timeout = 60"})
    render.buffer(buf)
    assert.same({[4] = highlight["delete-group"], [5] = highlight["add-group"]}, line_groups(buf))
    return assert.equals("@number", captures_on(buf, 4)["30"])
  end
  it("highlights a fugitive status buffer", _15_)
  local function _16_()
    local buf = diff_buffer("fugitive", {"Unstaged (1)", "U a.lua", "@@@ -1,3 -1,3 +1,3 @@@", "  local m = {}", "- local timeout = 30", " -local timeout = 45", "++local timeout = 60", "  return m"})
    render.buffer(buf)
    assert.same({[4] = highlight["delete-group"], [5] = highlight["delete-group"], [6] = highlight["add-group"]}, line_groups(buf))
    assert.equals("@keyword", captures_on(buf, 6)["local"])
    assert.equals("@number", captures_on(buf, 6)["60"])
    assert.equals("@number", captures_on(buf, 4)["30"])
    return assert.is_nil(captures_on(buf, 6)["+"])
  end
  it("highlights a combined diff in a status buffer", _16_)
  local function _17_()
    local buf = diff_buffer("git", one_file)
    render.buffer(buf)
    local before = #marks(buf)
    render.buffer(buf)
    return assert.equals(before, #marks(buf))
  end
  it("replaces the highlights rather than stacking them", _17_)
  local function _18_()
    local buf = diff_buffer("git", {"diff --git a/a.lua b/a.lua", "--- a/a.lua", "+++ b/a.lua", "@@ -1,4 +1,4 @@", " local m = {}", "", "-local timeout = 30", "+local timeout = 60"})
    render.buffer(buf)
    assert.same({[6] = highlight["delete-group"], [7] = highlight["add-group"]}, line_groups(buf))
    return assert.equals("@number", captures_on(buf, 6)["30"])
  end
  it("colors past an empty context line", _18_)
  local function _19_()
    local buf = diff_buffer("git", {"diff --git a/a.zzunknown b/a.zzunknown", "--- a/a.zzunknown", "+++ b/a.zzunknown", "@@ -1 +1 @@", "-old text", "+new text"})
    render.buffer(buf)
    return assert.same({[4] = highlight["delete-group"], [5] = highlight["add-group"]}, line_groups(buf))
  end
  it("still colors lines when the language has no parser", _19_)
  local function _20_()
    local buf = diff_buffer("git", {"commit abc123", "Author: Nobody"})
    render.buffer(buf)
    return assert.equals(0, #marks(buf))
  end
  return it("does nothing to a buffer with no hunk", _20_)
end
describe("buffer", _10_)
local function _21_()
  local function _22_()
    local buf = diff_buffer("git", {"diff --git a/a.lua b/a.lua", "--- a/a.lua", "+++ b/a.lua", "@@ -1,3 +1,3 @@", "-function foo(a)", "+function foo(a, b)", "   return a", " end"})
    render.buffer(buf)
    assert.equals("@keyword.function", captures_on(buf, 4)["function"])
    return assert.equals("@keyword.function", captures_on(buf, 5)["function"])
  end
  it("keeps the other side's lines out of the parse", _22_)
  local function _23_()
    local buf = diff_buffer("git", {"diff --git a/a.lua b/a.c", "similarity index 50%", "rename from a.lua", "rename to a.c", "--- a/a.lua", "+++ b/a.c", "@@ -1 +1 @@", "-local x = 1", "+int x = 1;"})
    render.buffer(buf)
    assert.equals("@keyword", captures_on(buf, 7)["local"])
    return assert.equals("@type.builtin", captures_on(buf, 8).int)
  end
  it("parses each side of a rename with its own parser", _23_)
  local function _24_()
    local buf = diff_buffer("git", one_file)
    render.buffer(buf)
    assert.same({}, duplicate_captures_on(buf, 4))
    assert.same({}, duplicate_captures_on(buf, 7))
    assert.equals("@keyword", captures_on(buf, 4)["local"])
    return assert.equals("@keyword.return", captures_on(buf, 7)["return"])
  end
  it("colors a context line once, not once per side", _24_)
  local function _25_()
    local buf = diff_buffer("git", {"diff --git a/a.md b/a.md", "--- a/a.md", "+++ b/a.md", "@@ -1,3 +1,3 @@", " ```lua", "-local timeout = 30", "+local timeout = 60", " ```"})
    render.buffer(buf)
    assert.equals("@keyword", captures_on(buf, 5)["local"])
    return assert.equals("@number", captures_on(buf, 6)["60"])
  end
  it("colors an injected language inside a hunk", _25_)
  local function _26_()
    local buf = diff_buffer("git", {"diff --git a/a.lua b/a.zzunknown", "--- a/a.lua", "+++ b/a.zzunknown", "@@ -1 +1 @@", "-local x = 1", "+whatever"})
    render.buffer(buf)
    assert.equals("@keyword", captures_on(buf, 4)["local"])
    return assert.is_nil(captures_on(buf, 5).whatever)
  end
  return it("colors a side whose file has no parser", _26_)
end
describe("per-side parsing", _21_)
local one_pair = {" 1:  1111111 ! 1:  2222222 fix: something", "      ## a.lua ##", "     @@", "      local m = {}", "     -local timeout = 30", "    -+local timeout = 45", "    ++local timeout = 60", "      return m"}
local function _27_()
  local function _28_()
    local buf = diff_buffer("git", one_pair)
    render.buffer(buf)
    return assert.same({[4] = highlight["delete-group"], [5] = highlight["add-dim-group"], [6] = highlight["add-group"]}, line_groups(buf))
  end
  it("colors the lines by the marker of the patch", _28_)
  local function _29_()
    local buf = diff_buffer("git", {" 1:  1111111 ! 1:  2222222 fix: x", "      ## a.lua ##", "     @@", "    --local dropped = 1", "    -+local old_add = 2", "     -local shared_del = 3", "    ++local new_add = 4", "    +-local new_del = 5"})
    render.buffer(buf)
    return assert.same({[3] = highlight["delete-dim-group"], [4] = highlight["add-dim-group"], [5] = highlight["delete-group"], [6] = highlight["add-group"], [7] = highlight["delete-group"]}, line_groups(buf))
  end
  it("dims only the lines that the earlier series alone holds", _29_)
  local function _30_()
    local buf = diff_buffer("git", one_pair)
    render.buffer(buf)
    assert.equals("@number", captures_on(buf, 5)["45"])
    assert.equals("@number", captures_on(buf, 6)["60"])
    assert.equals("@keyword", captures_on(buf, 5)["local"])
    return assert.equals("@keyword", captures_on(buf, 6)["local"])
  end
  it("parses each series apart from the other", _30_)
  local function _31_()
    local buf = diff_buffer("git", one_pair)
    render.buffer(buf)
    assert.equals("@number", captures_on(buf, 4)["30"])
    assert.is_nil(captures_on(buf, 6)["+"])
    return assert.is_nil(captures_on(buf, 5)["-+"])
  end
  it("strips both markers", _31_)
  local function _32_()
    local buf = diff_buffer("git", one_pair)
    render.buffer(buf)
    assert.same({}, duplicate_captures_on(buf, 3))
    assert.same({}, duplicate_captures_on(buf, 4))
    assert.same({}, duplicate_captures_on(buf, 7))
    assert.equals("@keyword", captures_on(buf, 3)["local"])
    return assert.equals("@keyword.return", captures_on(buf, 7)["return"])
  end
  return it("colors a line that both series hold once", _32_)
end
describe("range-diff output", _27_)
local function _33_()
  local function _34_()
    local buf = diff_buffer("git", one_file)
    render.buffer(buf)
    assert.is_true((0 < #marks(buf)))
    render.clear(buf)
    return assert.equals(0, #marks(buf))
  end
  return it("removes every highlight the plugin placed", _34_)
end
return describe("clear", _33_)
