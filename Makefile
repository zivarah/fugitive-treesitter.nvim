# Every Fennel source. `.deps` holds cloned dependencies, not our own code.
FNL := $(shell find . -name '*.fnl' -not -path './.deps/*')

# The Neovim plugins that the build and the specs need. Everything else (nvim,
# fnlfmt, fennel-ls, etc.) is expected on PATH.
DEPS    := .deps
PLENARY := $(DEPS)/plugins/plenary.nvim
NFNL    := $(DEPS)/plugins/nfnl

PLENARY_URL := https://github.com/nvim-lua/plenary.nvim
PLENARY_REV := 74b06c6c75e4eeb3108ec01852001636d85a932b
NFNL_URL := https://github.com/Olical/nfnl
NFNL_REV := ac0177c5549df7abba7a19554c18a7765386c894

# `make tools` builds the lint tools here. They live under one directory because
# spec/minimal-init.lua adds every $(DEPS) entry to the Neovim runtimepath.
TOOLS       := $(DEPS)/tools
TOOLS_BIN   := $(TOOLS)/bin
TOOLS_SHARE := $(TOOLS)/share
FNLFMT      := $(TOOLS)/fnlfmt
FENNEL_LS   := $(TOOLS)/fennel-ls
DOCSETS     := $(TOOLS_SHARE)/fennel-ls/docsets

# fnlfmt 0.3.3-dev. The 0.3.2 release formats a few forms differently, so keep
# this revision the same as the one in shell.nix.
FNLFMT_URL := https://git.sr.ht/~technomancy/fnlfmt
FNLFMT_REV := e059775b9ce38cdcf3c1d5458ca2e5f2ecf698b3
# fennel-ls 0.2.3
FENNEL_LS_URL := https://git.sr.ht/~xerool/fennel-ls
FENNEL_LS_REV := 44f931d38da301bbabd107f4d00cce9920b03b9c
# Docset so that fennel-ls recognizes nvim APIs
NVIM_DOCSET_URL := https://git.sr.ht/~micampe/fennel-ls-nvim-docs
NVIM_DOCSET_REV := a072d3f5d2dd98cf0411cd16446a0f3c96ee7938

.PHONY: all
all: fmt lint build test

$(PLENARY):
	git -c advice.detachedHead=false clone --filter=blob:none --revision=$(PLENARY_REV) $(PLENARY_URL) $@

$(NFNL):
	git -c advice.detachedHead=false clone --filter=blob:none --revision=$(NFNL_REV) $(NFNL_URL) $@

.PHONY: deps
deps: $(PLENARY) $(NFNL)

$(FNLFMT):
	git -c advice.detachedHead=false clone --filter=blob:none --revision=$(FNLFMT_REV) $(FNLFMT_URL) $@

$(FENNEL_LS):
	git -c advice.detachedHead=false clone --filter=blob:none --revision=$(FENNEL_LS_REV) $(FENNEL_LS_URL) $@

$(TOOLS_BIN)/fnlfmt: | $(FNLFMT)
	$(MAKE) -C $(FNLFMT) fnlfmt
	@mkdir -p $(TOOLS_BIN)
	ln -sf ../fnlfmt/fnlfmt $@

$(TOOLS_BIN)/fennel-ls: | $(FENNEL_LS)
	$(MAKE) -C $(FENNEL_LS) fennel-ls
	@mkdir -p $(TOOLS_BIN)
	ln -sf ../fennel-ls/fennel-ls $@

# The docset repository puts nvim.lua at its root, which is the layout
# fennel-ls expects under $XDG_DATA_HOME/fennel-ls/docsets.
$(DOCSETS):
	git -c advice.detachedHead=false clone --filter=blob:none --revision=$(NVIM_DOCSET_REV) $(NVIM_DOCSET_URL) $@

# Builds fnlfmt and fennel-ls from source and fetches the docsets they need, for
# CI and for anyone who does not want to install them another way. `lua` must be
# on PATH. `make lint` reads the tools from PATH and the docsets from
# $XDG_DATA_HOME, so set both to point here afterwards:
#
#     PATH=$(TOOLS_BIN):$$PATH XDG_DATA_HOME=$(TOOLS_SHARE) make lint
.PHONY: tools
tools: $(TOOLS_BIN)/fnlfmt $(TOOLS_BIN)/fennel-ls $(DOCSETS)

.PHONY: build
build: $(NFNL)
	@nvim -u NONE --cmd 'set runtimepath+=$(NFNL)' -l script/compile.lua

.PHONY: fmt
fmt:
	@fnlfmt --fix $(FNL)

# fnlfmt's man page indicates that `fnlfmt --check` should exit non-zero if
# things aren't formatted, but in practice that isn't the case (as of v0.3.2).
.PHONY: lint
lint:
	@if fnlfmt --check $(FNL) 2>&1 | grep .; then echo 'Run `make fmt`.'; exit 1; fi
	@fennel-ls --lint $(FNL)

.PHONY: test
test: $(PLENARY) build
	@nvim --headless --noplugin -u spec/minimal-init.lua \
		-c "PlenaryBustedDirectory spec/lua/ { minimal_init = 'spec/minimal-init.lua' }"

.PHONY: clean
clean:
	rm -rf $(DEPS)
