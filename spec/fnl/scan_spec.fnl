(local {: describe : it} (require :plenary.busted))
(local assert (require :luassert.assert))
(local scan (require :fugitive-treesitter.scan))

(fn git [lines]
  "Scan lines as `git`-format diff output."
  (scan.regions lines :git))

(fn status [lines]
  "Scan lines as a fugitive status buffer."
  (scan.regions lines :fugitive))

(describe :body-prefix?
          (fn []
            (it "accepts the three hunk body markers"
                (fn []
                  (assert.is_true (scan.body-prefix? "+"))
                  (assert.is_true (scan.body-prefix? "-"))
                  (assert.is_true (scan.body-prefix? " "))))
            (it "accepts an empty line as a blank context line"
                (fn []
                  (assert.is_true (scan.body-prefix? ""))))
            (it "rejects anything else"
                (fn []
                  (assert.is_false (scan.body-prefix? "@"))
                  (assert.is_false (scan.body-prefix? "\\"))))))

(describe :line-kind
          (fn []
            (it "reads an ordinary marker"
                (fn []
                  (assert.equals :add (scan.line-kind "+"))
                  (assert.equals :delete (scan.line-kind "-"))
                  (assert.equals :context (scan.line-kind " "))
                  (assert.equals :context (scan.line-kind ""))))
            (it "reads a combined marker from any column"
                (fn []
                  (assert.equals :add (scan.line-kind "++"))
                  (assert.equals :add (scan.line-kind "+ "))
                  (assert.equals :add (scan.line-kind " +"))
                  (assert.equals :delete (scan.line-kind "--"))
                  (assert.equals :delete (scan.line-kind "- "))
                  (assert.equals :delete (scan.line-kind " -"))
                  (assert.equals :context (scan.line-kind "  "))))))

(describe "regions in git format"
          (fn []
            (it "finds the body of one hunk"
                (fn []
                  (let [regions (git ["diff --git a/lua/foo.lua b/lua/foo.lua"
                                      "index 1111111..2222222 100644"
                                      "--- a/lua/foo.lua"
                                      "+++ b/lua/foo.lua"
                                      "@@ -1,3 +1,3 @@"
                                      " local m = {}"
                                      "-local a = 1"
                                      "+local a = 2"
                                      " return m"])]
                    (assert.equals 1 (length regions))
                    (assert.same {:first 5
                                  :last 9
                                  :marker-width 1
                                  :text-col 1
                                  :series [:context]
                                  :series-width 0
                                  :old-path :lua/foo.lua
                                  :new-path :lua/foo.lua}
                                 (. regions 1)))))
            (it "keeps the no-newline marker in the body"
                (fn []
                  (let [regions (git ["diff --git a/a.lua b/a.lua"
                                      "--- a/a.lua"
                                      "+++ b/a.lua"
                                      "@@ -1 +1 @@"
                                      "-local a = 1"
                                      "\\ No newline at end of file"
                                      "+local a = 2"])]
                    (assert.equals 1 (length regions))
                    (assert.equals 4 (. regions 1 :first))
                    (assert.equals 7 (. regions 1 :last)))))
            (it "keeps an empty context line in the body"
                (fn []
                  ;; Under `diff.suppressBlankEmpty` git writes a blank context
                  ;; line with no leading space, and the body carries on below
                  ;; it.
                  (let [regions (git ["diff --git a/a.lua b/a.lua"
                                      "--- a/a.lua"
                                      "+++ b/a.lua"
                                      "@@ -1,4 +1,4 @@"
                                      " local m = {}"
                                      ""
                                      "-local a = 1"
                                      "+local a = 2"])]
                    (assert.equals 1 (length regions))
                    (assert.equals 4 (. regions 1 :first))
                    (assert.equals 8 (. regions 1 :last)))))
            (it "keeps header-shaped source lines in the body"
                (fn []
                  (let [regions (git ["diff --git a/a.lua b/a.lua"
                                      "--- a/a.lua"
                                      "+++ b/a.lua"
                                      "@@ -1 +1 @@"
                                      "--- tricky old"
                                      "+++ trick new"])]
                    (assert.equals 1 (length regions))
                    (assert.equals 4 (. regions 1 :first))
                    (assert.equals 6 (. regions 1 :last)))))
            (it "strips a one-letter directory prefix"
                (fn []
                  (let [regions (git ["diff --git a/a.lua b/a.lua"
                                      "--- i/a.lua"
                                      "+++ w/a.lua"
                                      "@@ -1 +1 @@"
                                      "-local a = 1"
                                      "+local a = 2"])]
                    (assert.equals :a.lua (. regions 1 :new-path)))))
            (it "uses the removed path for both sides of a deleted file"
                (fn []
                  (let [regions (git ["diff --git a/old.lua b/old.lua"
                                      "deleted file mode 100644"
                                      "--- a/old.lua"
                                      "+++ /dev/null"
                                      "@@ -1,2 +0,0 @@"
                                      "-local x = 1"
                                      "-return x"])]
                    (assert.equals :old.lua (. regions 1 :old-path))
                    (assert.equals :old.lua (. regions 1 :new-path)))))
            (it "uses the added path for both sides of a new file"
                (fn []
                  (let [regions (git ["diff --git a/new.lua b/new.lua"
                                      "new file mode 100644"
                                      "--- /dev/null"
                                      "+++ b/new.lua"
                                      "@@ -0,0 +1,2 @@"
                                      "+local x = 1"
                                      "+return x"])]
                    (assert.equals :new.lua (. regions 1 :old-path))
                    (assert.equals :new.lua (. regions 1 :new-path)))))
            (it "keeps both paths of a rename"
                (fn []
                  (let [regions (git ["diff --git a/old.js b/new.ts"
                                      "similarity index 80%"
                                      "rename from old.js"
                                      "rename to new.ts"
                                      "--- a/old.js"
                                      "+++ b/new.ts"
                                      "@@ -1 +1 @@"
                                      "-var a = 1"
                                      "+const a: number = 1"])]
                    (assert.equals :old.js (. regions 1 :old-path))
                    (assert.equals :new.ts (. regions 1 :new-path)))))
            (it "keeps a path that contains a slash-prefixed directory"
                (fn []
                  (let [regions (git ["diff --git a/lua/a/b.lua b/lua/a/b.lua"
                                      "--- a/lua/a/b.lua"
                                      "+++ b/lua/a/b.lua"
                                      "@@ -1 +1 @@"
                                      "-local a = 1"
                                      "+local a = 2"])]
                    (assert.equals :lua/a/b.lua (. regions 1 :new-path)))))
            (it "finds one region per file"
                (fn []
                  (let [regions (git ["diff --git a/a.lua b/a.lua"
                                      "--- a/a.lua"
                                      "+++ b/a.lua"
                                      "@@ -1 +1 @@"
                                      "-local a = 1"
                                      "+local a = 2"
                                      "diff --git a/b.lua b/b.lua"
                                      "--- a/b.lua"
                                      "+++ b/b.lua"
                                      "@@ -1 +1 @@"
                                      "-local b = 1"
                                      "+local b = 2"])]
                    (assert.equals 2 (length regions))
                    (assert.equals :a.lua (. regions 1 :new-path))
                    (assert.equals :b.lua (. regions 2 :new-path)))))
            (it "finds both hunks of one file"
                (fn []
                  (let [regions (git ["diff --git a/a.lua b/a.lua"
                                      "--- a/a.lua"
                                      "+++ b/a.lua"
                                      "@@ -1 +1 @@"
                                      "-local a = 1"
                                      "+local a = 2"
                                      "@@ -9 +9 @@"
                                      "-local b = 1"
                                      "+local b = 2"])]
                    (assert.equals 2 (length regions))
                    (assert.equals :a.lua (. regions 1 :new-path))
                    (assert.equals :a.lua (. regions 2 :new-path)))))
            (it "reads the marker width of a combined diff"
                (fn []
                  ;; A combined diff header contains one `@` per parent plus
                  ;; one.
                  (let [regions (git ["diff --cc a.lua"
                                      "--- a/a.lua"
                                      "+++ b/a.lua"
                                      "@@@ -1,2 -1,2 +1,2 @@@"
                                      "- local timeout = 30"
                                      " -local timeout = 45"
                                      "++local timeout = 60"])]
                    (assert.equals 1 (length regions))
                    (assert.equals 2 (. regions 1 :marker-width)))))
            (it "gives nothing for a hunk with no file header"
                (fn []
                  (assert.same {}
                               (git ["@@ -1 +1 @@"
                                     "-local a = 1"
                                     "+local a = 2"]))))
            (it "gives nothing for a header with an empty body"
                (fn []
                  (assert.same {}
                               (git ["diff --git a/a.lua b/a.lua"
                                     "--- a/a.lua"
                                     "+++ b/a.lua"
                                     "@@ -0,0 +0,0 @@"]))))
            (it "gives nothing for a buffer with no hunk"
                (fn []
                  (assert.same {} (git []))
                  (assert.same {} (git ["commit abc123" "Author: Someone"]))))))

(local one-pair [" 1:  1111111 ! 1:  2222222 fix: something"
                 "    @@ Metadata"
                 "     Author: Someone <someone@example.com>"
                 "     "
                 "      ## Commit message ##"
                 "    -    fix: old subject"
                 "    +    fix: new subject"
                 "     "
                 "      ## a.lua ##"
                 "     @@"
                 "      local m = {}"
                 "     -local timeout = 30"
                 "    -+local timeout = 45"
                 "    ++local timeout = 60"
                 "      return m"])

(describe "regions in range-diff output"
          (fn []
            (it "finds the body of one hunk"
                (fn []
                  (let [regions (git one-pair)]
                    (assert.equals 1 (length regions))
                    (assert.same {:first 10
                                  :last 15
                                  :marker-width 1
                                  :text-col 6
                                  :series [:delete :add]
                                  :series-width 1
                                  :old-path :a.lua
                                  :new-path :a.lua}
                                 (. regions 1)))))
            (it "gives nothing for the sections that stand in for a file"
                (fn []
                  ;; The `Metadata` and `Commit message` sections contain prose,
                  ;; so
                  ;; they must not be parsed as code.
                  (let [regions (git [" 1:  1111111 ! 1:  2222222 fix: x"
                                      "    @@ Metadata"
                                      "     Author: Someone <s@example.com>"
                                      "      ## Commit message ##"
                                      "    -    fix: old subject"
                                      "    +    fix: new subject"])]
                    (assert.same {} regions))))
            (it "takes the path from a hunk header of the outer diff"
                (fn []
                  ;; The outer diff shows the `## path ##` line only when it is
                  ;; close enough to a difference, so its own hunk header is
                  ;; sometimes the only place the path appears. The code that
                  ;; follows the path after a colon is not part of it.
                  (let [regions (git [" 1:  1111111 ! 1:  2222222 fix: x"
                                      "    @@ b.lua: local function foo()"
                                      "      local m = {}"
                                      "     -local timeout = 30"
                                      "    ++local timeout = 60"])]
                    (assert.equals 1 (length regions))
                    (assert.equals :b.lua (. regions 1 :new-path))
                    (assert.equals 2 (. regions 1 :first))
                    (assert.equals 5 (. regions 1 :last)))))
            (it "drops the note on a file that a patch creates or removes"
                (fn []
                  ;; A range-diff writes `path (new)` and `path (deleted)`. The
                  ;; note is not part of the path, and no filetype matches it.
                  (let [regions (git [" 1:  1111111 ! 1:  2222222 fix: x"
                                      "      ## a.lua (new) ##"
                                      "     @@"
                                      "    ++local timeout = 60"
                                      "      ## b.lua (deleted) ##"
                                      "     @@"
                                      "    --local dropped = 1"])]
                    (assert.equals 2 (length regions))
                    (assert.equals :a.lua (. regions 1 :new-path))
                    (assert.equals :b.lua (. regions 2 :new-path)))))
            (it "keeps a path whose own name ends in brackets"
                (fn []
                  (let [regions (git [" 1:  1111111 ! 1:  2222222 fix: x"
                                      "      ## notes (draft).md ##"
                                      "     @@"
                                      "    ++# heading"])]
                    (assert.equals "notes (draft).md" (. regions 1 :new-path)))))
            (it "reads ordinary diff output as an ordinary diff"
                (fn []
                  ;; A range-diff has the `git` filetype too, so the format
                  ;; comes from the content. Ordinary output must not match.
                  (let [regions (git ["diff --git a/a.lua b/a.lua"
                                      "--- a/a.lua"
                                      "+++ b/a.lua"
                                      "@@ -1 +1 @@"
                                      "-local a = 1"
                                      "+local a = 2"])]
                    (assert.equals 1 (. regions 1 :marker-width))
                    (assert.equals 1 (. regions 1 :text-col)))))))

(describe "regions in a fugitive status buffer"
          (fn []
            (it "takes the path from a status entry"
                (fn []
                  (let [regions (status ["Head: main"
                                         ""
                                         "Unstaged (1)"
                                         "M lua/foo.lua"
                                         "@@ -1,2 +1,2 @@"
                                         "-local a = 1"
                                         "+local a = 2"])]
                    (assert.equals 1 (length regions))
                    (assert.same {:first 5
                                  :last 7
                                  :marker-width 1
                                  :text-col 1
                                  :series [:context]
                                  :series-width 0
                                  :old-path :lua/foo.lua
                                  :new-path :lua/foo.lua}
                                 (. regions 1)))))
            (it "splits both paths of a rename entry"
                (fn []
                  (let [regions (status ["Staged (1)"
                                         "R old.js -> new.ts"
                                         "@@ -1 +1 @@"
                                         "-var a = 1"
                                         "+const a: number = 1"])]
                    (assert.equals :old.js (. regions 1 :old-path))
                    (assert.equals :new.ts (. regions 1 :new-path)))))
            (it "uses one path for both sides of a plain entry"
                (fn []
                  (let [regions (status ["Unstaged (1)"
                                         "M a.lua"
                                         "@@ -1 +1 @@"
                                         "-local a = 1"
                                         "+local a = 2"])]
                    (assert.equals :a.lua (. regions 1 :old-path))
                    (assert.equals :a.lua (. regions 1 :new-path)))))
            (it "handles an untracked entry"
                (fn []
                  (let [regions (status ["Untracked (1)"
                                         "? new.lua"
                                         "@@ -0,0 +1 @@"
                                         "+local a = 1"])]
                    (assert.equals :new.lua (. regions 1 :new-path)))))
            (it "does not read a git-format header as a path"
                (fn []
                  (assert.same {}
                               (status ["--- a/a.lua"
                                        "+++ b/a.lua"
                                        "@@ -1 +1 @@"
                                        "-local a = 1"
                                        "+local a = 2"]))))))
