# fugitive-treesitter.nvim

Treesitter syntax highlighting for the code inside [vim-fugitive][fugitive]
diffs.

## Requirements

- Neovim 0.12 or newer
- [vim-fugitive][fugitive]
- An installed treesitter parser for each language you want highlighted

[vim-fugitive][fugitive] is not actually a runtime dependency, but this plugin
won't be very useful without it.

## Installation

### lazy.nvim

```lua
{
    "zivarah/fugitive-treesitter.nvim",
}
```

### vim.pack

```lua
vim.pack.add({
  "https://github.com/zivarah/fugitive-treesitter.nvim",
})
```

## Documentation

See [`:help fugitive-treesitter`][vimdoc] for:

- configuration options
- highlight groups to customize as needed
- Lua APIs
- etc.

## Troubleshooting

```vim
:checkhealth fugitive-treesitter
```

## Troubleshooting

```vim
:checkhealth fugitive-treesitter
```

## Credits

[vim-fugitive][fugitive] provides the buffers that this plugin integrates with.

The idea and general approach is borrowed from [Neogit][neogit].

## License

MIT. See [LICENSE](LICENSE).

[vimdoc]: ./doc/fugitive-treesitter.txt
[fugitive]: https://github.com/tpope/vim-fugitive
[neogit]: https://github.com/NeogitOrg/neogit
