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
      })
    end,
  }
})
```

Configuration
- `enabled` (boolean): whether to set `vim.opt.spell` during setup.
- `spelllang` (table): value for `vim.opt.spelllang`, e.g. `{ 'en_us' }`.
- `spellfile` (string or table): path(s) to persistent spellfile(s). Defaults to `$XDG_CONFIG_HOME/nvim/spell/custom.en.utf-8.add`.

Commands

| Command | Description |
| --- | --- |
| `:SpellSuggest` | Show suggestions for the current word and optionally replace it (uses `vim.ui.select`). |
| `:SpellNext` `:SpellPrev` | Jump to the next / previous misspelled word (same as `]s` / `[s`). |
| `:SpellAdd` `:SpellAdd!` | Mark the current word as correct; use `!` to persist the word to the configured `spellfile`. |
| `:SpellDisable` `:SpellEnable` `:SpellTogglePlugin` | Disable, enable, or toggle plugin behavior (turns Neovim's `spell` option on/off when configured). |
