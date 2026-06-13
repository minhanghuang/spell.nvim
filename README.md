# nvim-spell

A Neovim spell-checking plugin powered by [cspell](https://cspell.org), using Neovim's built-in `vim.diagnostic` API for displaying results.

## Requirements

- [cspell](https://cspell.org) CLI (`npm install -g cspell`)

## Installation (lazy.nvim)

```lua
{
  'minhanghuang/spell.nvim',
  event = 'VeryLazy',
  config = function()
    require('nvim-spell').setup()
  end,
}
```

## Configuration

```lua
require('nvim-spell').setup({
  -- Language locale(s), e.g. 'en-US', 'en,zh-cn' (default: nil)
  locale = nil,

  -- cspell dictionaries: bundled, no extra install needed
  -- Important: always include 'en_us' (or 'en-gb') for base word recognition
  dictionaries = { 'en_us', 'lua', 'bash', 'softwareTerms' },

  -- cspell binary path (default: 'cspell')
  cspell_cmd = 'cspell',

  -- cspell config file (default: auto-detect → ~/.config/nvim/spell/cspell.json)
  config_file = nil,

  -- Run on save / while typing
  check_on_save = true,
  check_on_change = false,      -- debounced, set true for real-time
  check_delay = 500,            -- debounce ms (only when check_on_change = true)

  -- Allowlist / denylist (both support string or table)
  filetypes = nil,              -- nil = all, or e.g. { 'markdown', 'text' }
  exclude_filetypes = {         -- file explorers & special buffers excluded by default
    'neo-tree', 'NvimTree', 'nerdtree', 'netrw', 'help', 'qf', 'lazy', 'mason',
  },

  -- Diagnostic severity level
  diagnostic_severity = vim.diagnostic.severity.INFO,
})
```

## Dictionaries

cspell bundles **60+ dictionaries** — no extra install needed. Always include `en_us` first:

| Dictionary | Covers |
|-----------|--------|
| `en_us` | American English (always include this) |
| `lua` | Lua / Neovim APIs |
| `bash`, `shell` | Shell scripts |
| `python`, `rust`, `typescript`, `golang` | Programming languages |
| `softwareTerms` | General dev jargon |
| `git`, `docker`, `npm` | Dev tools |
| `markdown`, `html`, `css` | Web / docs |
| `companies` | Company names |

## Commands

| Command | Description |
| --- | --- |
| `:SpellSuggest` | Show suggestions for the current word and optionally replace it (`vim.ui.select`). |
| `:SpellNext` `:SpellPrev` | Jump to the next / previous misspelled word. |
| `:SpellAdd` | Mark the current word as correct for this session. |
| `:SpellAdd!` | Persist the word to the cspell config file (`cspell.json`). |
| `:SpellCheck` | Run cspell on the current buffer and show diagnostics. |
| `:SpellCheckBuffer` | Run cspell and populate the quickfix list. |
| `:SpellDisable` `:SpellEnable` `:SpellTogglePlugin` | Disable, enable, or toggle plugin behavior. |

## How It Works

- **Diagnostics**: `cspell lint` runs asynchronously on buffer content and results are displayed via `vim.diagnostic`.
- **Suggestions**: `cspell suggestions <word>` provides correction candidates.
- **Dictionary**: `:SpellAdd!` writes to the nearest `cspell.json` (project root or `~/.config/nvim/spell/`).
- **Config file**: Auto-detected from project directories, or set via `config_file` option. Auto-created on first `setup()`.
- **Navigation**: Uses `vim.diagnostic.goto_next` / `goto_prev` for jumping between errors.

## Development

```bash
npm install -g cspell   # required for tests
make test                # run all tests
```
