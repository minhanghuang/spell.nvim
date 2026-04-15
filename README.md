# nvim-spell

A small Neovim plugin that provides convenient commands
for working with Neovim's built-in spell checking.

Features
- Uses Neovim's built-in `spell`/`spellsuggest`/`spellbadword` APIs.
- Ignores CJK words by default (heuristic) when suggesting corrections.
- Persistent user dictionary support via a configurable `spellfile` (default: `~/.config/nvim/spell/custom.en.utf-8.add`).
-- Useful commands for quick fixes and navigation.

Installation(lazy.nvim)
```lua
require('lazy').setup({
  {
    'minhanghuang/spell.nvim',
    event = 'VeryLazy',
    config = function()
      require('nvim-spell').setup({
        enabled = true,
        spelllang = { 'en_us,cjk' },
        -- spellfile = vim.fn.stdpath('config') .. '/spell/custom.en.utf-8.add', -- optional
        -- exclude_filetypes = { 'my_custom_filetype' }, -- optional: additional filetypes to exclude
      })
    end,
  }
})
```

Configuration
- `enabled` (boolean): whether to set `vim.opt.spell` during setup.
- `spelllang` (table): value for `vim.opt.spelllang`, e.g. `{ 'en_us' }`.
- `spellfile` (string or table): path(s) to persistent spellfile(s). Defaults to `$XDG_CONFIG_HOME/nvim/spell/custom.en.utf-8.add`.
- `exclude_filetypes` (table, optional): additional filetypes to exclude from spell checking. File trees, terminals, and other special buffers are excluded by default.

Commands

| Command | Description |
| --- | --- |
| `:SpellSuggest` | Show suggestions for the current word and optionally replace it (uses `vim.ui.select`). |
| `:SpellNext` `:SpellPrev` | Jump to the next / previous misspelled word (same as `]s` / `[s`). |
| `:SpellAdd` `:SpellAdd!` | Mark the current word as correct; use `!` to persist the word to the configured `spellfile`. |
| `:SpellDisable` `:SpellEnable` `:SpellTogglePlugin` | Disable, enable, or toggle plugin behavior. **Synchronizes across all windows and buffers** - when disabled in one window, all windows are disabled. |

## Features

### Multi-Window Synchronization

The plugin automatically synchronizes spell checking state across all windows and buffers:
- When you disable spell checking in one window (`:SpellDisable`), it's disabled in **all** windows
- When you enable spell checking (`:SpellEnable`), it's enabled in **all** windows
- New windows/buffers automatically inherit the current spell checking state
- No need to manually enable/disable spell checking for each window

### Smart Window Exclusion

The plugin automatically excludes special windows from spell checking:
- **File trees**: NvimTree, neo-tree, nerdtree, CHADTree, fern
- **Terminals**: terminal buffers, toggleterm
- **Special buffers**: quickfix, help, man pages, lspinfo
- **Plugins**: Telescope, fugitive, Trouble, aerial, dashboard, etc.
- **Custom exclusions**: Add your own filetypes via `exclude_filetypes` config option

This means your file tree and terminal windows won't have spell checking enabled even when you enable it globally.

## Development

### Running Tests

This plugin uses [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for testing.

```bash
# Run all tests
make test
```

Test coverage includes:
- Basic setup and configuration
- CJK character detection (Chinese, Japanese, Korean)
- Word replacement with cursor at different positions
- Buffer spell checking with quickfix integration
- Navigation between misspelled words
- Multi-window spell state synchronization
- Smart exclusion of file trees and special windows
