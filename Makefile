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

.PHONY: all
all: fmt lint build test

$(PLENARY):
	git -c advice.detachedHead=false clone --filter=blob:none --revision=$(PLENARY_REV) $(PLENARY_URL) $@

$(NFNL):
	git -c advice.detachedHead=false clone --filter=blob:none --revision=$(NFNL_REV) $(NFNL_URL) $@

.PHONY: deps
deps: $(PLENARY) $(NFNL)

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
