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
| `make build` | Compiles all fennel source to lua              |
| `make test`  | Runs all tests                                 |
| `make fmt`   | Formats every `.fnl` in place with `fnlfmt`    |
| `make lint`  | Runs `fnlfmt` and `fennel-ls` checks           |
| `make all`   | `fmt`, `lint`, `build`, and `test`             |
| `make clean` | Removes `.deps`                                |

You need these on your PATH:

- [fnlfmt][fnlfmt]
- [fennel-ls][fennel-ls]

[fennel]: https://fennel-lang.org
[fennel-ls]: https://git.sr.ht/~xerool/fennel-ls
[fnlfmt]: https://git.sr.ht/~technomancy/fnlfmt
[nfnl]: https://github.com/Olical/nfnl
