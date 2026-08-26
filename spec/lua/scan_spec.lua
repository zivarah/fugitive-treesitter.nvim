-- [nfnl] spec/fnl/scan_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local assert = require("luassert.assert")
local scan = require("fugitive-treesitter.scan")
local function git(lines)
  return scan.regions(lines, "git")
end
local function status(lines)
  return scan.regions(lines, "fugitive")
end
local function _2_()
  local function _3_()
    assert.is_true(scan["body-prefix?"]("+"))
    assert.is_true(scan["body-prefix?"]("-"))
    return assert.is_true(scan["body-prefix?"](" "))
  end
  it("accepts the three hunk body markers", _3_)
  local function _4_()
    return assert.is_true(scan["body-prefix?"](""))
  end
  it("accepts an empty line as a blank context line", _4_)
  local function _5_()
    assert.is_false(scan["body-prefix?"]("@"))
    return assert.is_false(scan["body-prefix?"]("\\"))
  end
  return it("rejects anything else", _5_)
end
describe("body-prefix?", _2_)
local function _6_()
  local function _7_()
    assert.equals("add", scan["line-kind"]("+"))
    assert.equals("delete", scan["line-kind"]("-"))
    assert.equals("context", scan["line-kind"](" "))
    return assert.equals("context", scan["line-kind"](""))
  end
  it("reads an ordinary marker", _7_)
  local function _8_()
    assert.equals("add", scan["line-kind"]("++"))
    assert.equals("add", scan["line-kind"]("+ "))
    assert.equals("add", scan["line-kind"](" +"))
    assert.equals("delete", scan["line-kind"]("--"))
    assert.equals("delete", scan["line-kind"]("- "))
    assert.equals("delete", scan["line-kind"](" -"))
    return assert.equals("context", scan["line-kind"]("  "))
  end
  return it("reads a combined marker from any column", _8_)
end
describe("line-kind", _6_)
local function _9_()
  local function _10_()
    local regions = git({"diff --git a/lua/foo.lua b/lua/foo.lua", "index 1111111..2222222 100644", "--- a/lua/foo.lua", "+++ b/lua/foo.lua", "@@ -1,3 +1,3 @@", " local m = {}", "-local a = 1", "+local a = 2", " return m"})
    assert.equals(1, #regions)
    return assert.same({first = 5, last = 9, ["marker-width"] = 1, ["text-col"] = 1, series = {"context"}, ["series-width"] = 0, ["old-path"] = "lua/foo.lua", ["new-path"] = "lua/foo.lua"}, regions[1])
  end
  it("finds the body of one hunk", _10_)
  local function _11_()
    local regions = git({"diff --git a/a.lua b/a.lua", "--- a/a.lua", "+++ b/a.lua", "@@ -1 +1 @@", "-local a = 1", "\\ No newline at end of file", "+local a = 2"})
    assert.equals(1, #regions)
    assert.equals(4, regions[1].first)
    return assert.equals(7, regions[1].last)
  end
  it("keeps the no-newline marker in the body", _11_)
  local function _12_()
    local regions = git({"diff --git a/a.lua b/a.lua", "--- a/a.lua", "+++ b/a.lua", "@@ -1,4 +1,4 @@", " local m = {}", "", "-local a = 1", "+local a = 2"})
    assert.equals(1, #regions)
    assert.equals(4, regions[1].first)
    return assert.equals(8, regions[1].last)
  end
  it("keeps an empty context line in the body", _12_)
  local function _13_()
    local regions = git({"diff --git a/a.lua b/a.lua", "--- a/a.lua", "+++ b/a.lua", "@@ -1 +1 @@", "--- tricky old", "+++ trick new"})
    assert.equals(1, #regions)
    assert.equals(4, regions[1].first)
    return assert.equals(6, regions[1].last)
  end
  it("keeps header-shaped source lines in the body", _13_)
  local function _14_()
    local regions = git({"diff --git a/a.lua b/a.lua", "--- i/a.lua", "+++ w/a.lua", "@@ -1 +1 @@", "-local a = 1", "+local a = 2"})
    return assert.equals("a.lua", regions[1]["new-path"])
  end
  it("strips a one-letter directory prefix", _14_)
  local function _15_()
    local regions = git({"diff --git a/old.lua b/old.lua", "deleted file mode 100644", "--- a/old.lua", "+++ /dev/null", "@@ -1,2 +0,0 @@", "-local x = 1", "-return x"})
    assert.equals("old.lua", regions[1]["old-path"])
    return assert.equals("old.lua", regions[1]["new-path"])
  end
  it("uses the removed path for both sides of a deleted file", _15_)
  local function _16_()
    local regions = git({"diff --git a/new.lua b/new.lua", "new file mode 100644", "--- /dev/null", "+++ b/new.lua", "@@ -0,0 +1,2 @@", "+local x = 1", "+return x"})
    assert.equals("new.lua", regions[1]["old-path"])
    return assert.equals("new.lua", regions[1]["new-path"])
  end
  it("uses the added path for both sides of a new file", _16_)
  local function _17_()
    local regions = git({"diff --git a/old.js b/new.ts", "similarity index 80%", "rename from old.js", "rename to new.ts", "--- a/old.js", "+++ b/new.ts", "@@ -1 +1 @@", "-var a = 1", "+const a: number = 1"})
    assert.equals("old.js", regions[1]["old-path"])
    return assert.equals("new.ts", regions[1]["new-path"])
  end
  it("keeps both paths of a rename", _17_)
  local function _18_()
    local regions = git({"diff --git a/lua/a/b.lua b/lua/a/b.lua", "--- a/lua/a/b.lua", "+++ b/lua/a/b.lua", "@@ -1 +1 @@", "-local a = 1", "+local a = 2"})
    return assert.equals("lua/a/b.lua", regions[1]["new-path"])
  end
  it("keeps a path that contains a slash-prefixed directory", _18_)
  local function _19_()
    local regions = git({"diff --git a/a.lua b/a.lua", "--- a/a.lua", "+++ b/a.lua", "@@ -1 +1 @@", "-local a = 1", "+local a = 2", "diff --git a/b.lua b/b.lua", "--- a/b.lua", "+++ b/b.lua", "@@ -1 +1 @@", "-local b = 1", "+local b = 2"})
    assert.equals(2, #regions)
    assert.equals("a.lua", regions[1]["new-path"])
    return assert.equals("b.lua", regions[2]["new-path"])
  end
  it("finds one region per file", _19_)
  local function _20_()
    local regions = git({"diff --git a/a.lua b/a.lua", "--- a/a.lua", "+++ b/a.lua", "@@ -1 +1 @@", "-local a = 1", "+local a = 2", "@@ -9 +9 @@", "-local b = 1", "+local b = 2"})
    assert.equals(2, #regions)
    assert.equals("a.lua", regions[1]["new-path"])
    return assert.equals("a.lua", regions[2]["new-path"])
  end
  it("finds both hunks of one file", _20_)
  local function _21_()
    local regions = git({"diff --cc a.lua", "--- a/a.lua", "+++ b/a.lua", "@@@ -1,2 -1,2 +1,2 @@@", "- local timeout = 30", " -local timeout = 45", "++local timeout = 60"})
    assert.equals(1, #regions)
    return assert.equals(2, regions[1]["marker-width"])
  end
  it("reads the marker width of a combined diff", _21_)
  local function _22_()
    return assert.same({}, git({"@@ -1 +1 @@", "-local a = 1", "+local a = 2"}))
  end
  it("gives nothing for a hunk with no file header", _22_)
  local function _23_()
    return assert.same({}, git({"diff --git a/a.lua b/a.lua", "--- a/a.lua", "+++ b/a.lua", "@@ -0,0 +0,0 @@"}))
  end
  it("gives nothing for a header with an empty body", _23_)
  local function _24_()
    assert.same({}, git({}))
    return assert.same({}, git({"commit abc123", "Author: Someone"}))
  end
  return it("gives nothing for a buffer with no hunk", _24_)
end
describe("regions in git format", _9_)
local one_pair = {" 1:  1111111 ! 1:  2222222 fix: something", "    @@ Metadata", "     Author: Someone <someone@example.com>", "     ", "      ## Commit message ##", "    -    fix: old subject", "    +    fix: new subject", "     ", "      ## a.lua ##", "     @@", "      local m = {}", "     -local timeout = 30", "    -+local timeout = 45", "    ++local timeout = 60", "      return m"}
local function _25_()
  local function _26_()
    local regions = git(one_pair)
    assert.equals(1, #regions)
    return assert.same({first = 10, last = 15, ["marker-width"] = 1, ["text-col"] = 6, series = {"delete", "add"}, ["series-width"] = 1, ["old-path"] = "a.lua", ["new-path"] = "a.lua"}, regions[1])
  end
  it("finds the body of one hunk", _26_)
  local function _27_()
    local regions = git({" 1:  1111111 ! 1:  2222222 fix: x", "    @@ Metadata", "     Author: Someone <s@example.com>", "      ## Commit message ##", "    -    fix: old subject", "    +    fix: new subject"})
    return assert.same({}, regions)
  end
  it("gives nothing for the sections that stand in for a file", _27_)
  local function _28_()
    local regions = git({" 1:  1111111 ! 1:  2222222 fix: x", "    @@ b.lua: local function foo()", "      local m = {}", "     -local timeout = 30", "    ++local timeout = 60"})
    assert.equals(1, #regions)
    assert.equals("b.lua", regions[1]["new-path"])
    assert.equals(2, regions[1].first)
    return assert.equals(5, regions[1].last)
  end
  it("takes the path from a hunk header of the outer diff", _28_)
  local function _29_()
    local regions = git({" 1:  1111111 ! 1:  2222222 fix: x", "      ## a.lua (new) ##", "     @@", "    ++local timeout = 60", "      ## b.lua (deleted) ##", "     @@", "    --local dropped = 1"})
    assert.equals(2, #regions)
    assert.equals("a.lua", regions[1]["new-path"])
    return assert.equals("b.lua", regions[2]["new-path"])
  end
  it("drops the note on a file that a patch creates or removes", _29_)
  local function _30_()
    local regions = git({" 1:  1111111 ! 1:  2222222 fix: x", "      ## notes (draft).md ##", "     @@", "    ++# heading"})
    return assert.equals("notes (draft).md", regions[1]["new-path"])
  end
  it("keeps a path whose own name ends in brackets", _30_)
  local function _31_()
    local regions = git({"diff --git a/a.lua b/a.lua", "--- a/a.lua", "+++ b/a.lua", "@@ -1 +1 @@", "-local a = 1", "+local a = 2"})
    assert.equals(1, regions[1]["marker-width"])
    return assert.equals(1, regions[1]["text-col"])
  end
  return it("reads ordinary diff output as an ordinary diff", _31_)
end
describe("regions in range-diff output", _25_)
local function _32_()
  local function _33_()
    local regions = status({"Head: main", "", "Unstaged (1)", "M lua/foo.lua", "@@ -1,2 +1,2 @@", "-local a = 1", "+local a = 2"})
    assert.equals(1, #regions)
    return assert.same({first = 5, last = 7, ["marker-width"] = 1, ["text-col"] = 1, series = {"context"}, ["series-width"] = 0, ["old-path"] = "lua/foo.lua", ["new-path"] = "lua/foo.lua"}, regions[1])
  end
  it("takes the path from a status entry", _33_)
  local function _34_()
    local regions = status({"Staged (1)", "R old.js -> new.ts", "@@ -1 +1 @@", "-var a = 1", "+const a: number = 1"})
    assert.equals("old.js", regions[1]["old-path"])
    return assert.equals("new.ts", regions[1]["new-path"])
  end
  it("splits both paths of a rename entry", _34_)
  local function _35_()
    local regions = status({"Unstaged (1)", "M a.lua", "@@ -1 +1 @@", "-local a = 1", "+local a = 2"})
    assert.equals("a.lua", regions[1]["old-path"])
    return assert.equals("a.lua", regions[1]["new-path"])
  end
  it("uses one path for both sides of a plain entry", _35_)
  local function _36_()
    local regions = status({"Untracked (1)", "? new.lua", "@@ -0,0 +1 @@", "+local a = 1"})
    return assert.equals("new.lua", regions[1]["new-path"])
  end
  it("handles an untracked entry", _36_)
  local function _37_()
    return assert.same({}, status({"--- a/a.lua", "+++ b/a.lua", "@@ -1 +1 @@", "-local a = 1", "+local a = 2"}))
  end
  return it("does not read a git-format header as a path", _37_)
end
return describe("regions in a fugitive status buffer", _32_)
