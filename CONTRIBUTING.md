# Contributing

The plugin is written in [Fennel][fennel] and compiled to Lua with [nfnl][nfnl].

The compiled Lua must be committed so that consumers don't need to build first.
Commit changes to the `.fnl` source and the regenerated `.lua` together. Install
the nfnl plugin in your own Neovim configuration and it does this on every save.

## Tooling

`make` has the following targets:

| Command      | What it does                                   |
| ------------ | ---------------------------------------------- |
| `make deps`  | Clones `plenary` and `nfnl` to `.deps/plugins` |
| `make tools` | Builds the lint tools to `.deps/tools`         |
| `make build` | Compiles all fennel source to lua              |
| `make test`  | Runs all tests                                 |
| `make fmt`   | Formats every `.fnl` in place with `fnlfmt`    |
| `make lint`  | Runs `fnlfmt` and `fennel-ls` checks           |
| `make all`   | `fmt`, `lint`, `build`, and `test`             |
| `make clean` | Removes `.deps`                                |

You need these on your PATH:

- [fnlfmt][fnlfmt]
- [fennel-ls][fennel-ls]

It is recommended that you install [fennel-ls-nvim-docs][nvim-docset] as well,
placing it at `$XDG_DATA_HOME/fennel-ls/docsets/nvim.lua`. `fennel-ls` will show
warnings otherwise (and `make lint` will fail).

If you do not want to install any of this yourself, `make tools` builds the
tools from source and fetches the docset, all at pinned revisions. It needs
`lua` on your PATH. Point PATH and `XDG_DATA_HOME` at the result afterwards,
which is what CI does:

```sh
PATH=.deps/tools/bin:$PATH XDG_DATA_HOME=.deps/tools/share make lint
```

[fennel]: https://fennel-lang.org
[fennel-ls]: https://git.sr.ht/~xerool/fennel-ls
[fnlfmt]: https://git.sr.ht/~technomancy/fnlfmt
[nfnl]: https://github.com/Olical/nfnl
[nvim-docset]: https://git.sr.ht/~micampe/fennel-ls-nvim-docs
