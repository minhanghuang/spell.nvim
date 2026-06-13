# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
make test          # Run all tests headlessly with plenary.nvim
```

Linting: stylua (`stylua --color always --check lua`). Config in `.stylua.toml`.

## Architecture

A Neovim plugin providing spell-checking on top of the `cspell` CLI (npm package). Uses Neovim's `vim.diagnostic` API for displaying results (replacing the previous `vim.spell`-based implementation).

```
plugin/nvim-spell.lua      — Registers user commands
lua/nvim-spell.lua         — Public API: setup(), enable(), disable(), toggle_plugin()
lua/nvim-spell/module.lua  — High-level logic: diagnostics, suggestions, word replacement, quickfix
lua/nvim-spell/cspell.lua  — Low-level cspell CLI integration (async lint, sync suggestions, config mgmt)
```

### `lua/nvim-spell/cspell.lua` — cspell CLI integration

- `is_cspell_available(cmd)` — checks if cspell is in PATH
- `find_config(buf)` — walks up from buffer to find cspell.json / .cspell.json / cspell.yaml
- `ensure_config(dir, cmd)` — creates cspell.json via `cspell init` if none found
- `run_lint(buf, config_path, callback, cmd)` — async lint via `vim.fn.jobstart`, pipes buffer content to `cspell lint stdin://... --reporter @cspell/cspell-json-reporter`
- `parse_lint_output(json_str)` — parses JSON reporter output into `{text, lnum, col, end_col, suggestions}` list
- `get_suggestions(word, config_path, cmd)` — sync via `vim.fn.system('cspell suggestions ...')`, parses text output
- `add_word(word, config_path)` — adds word to cspell.json `words` array (with dedup)
- `word_in_config(word, config_path)` — checks if word exists in config's `words` or `ignoreWords`

### `lua/nvim-spell/module.lua` — High-level spell logic

- `check_buffer_diagnostics(buf)` — async lint → `vim.diagnostic.set()` with `nvim-spell` namespace
- `check_buffer_to_qf()` — async lint → populate quickfix list
- `check_word(word)` / `check_current_word()` — sync check using cspell suggestions (first suggestion == word → correct)
- `replace_current_word(replacement)` — replaces word at cursor using `viw` visual selection + `nvim_buf_set_text`
- `suggest_and_replace_current()` — `cspell suggestions` → `vim.ui.select` → replace on choice
- `goto_next_misspelled()` / `goto_prev_misspelled()` — wraps `vim.diagnostic.goto_next/prev`
- `add_current_word(persist)` — adds to cspell.json (persist=true) or session-only in-memory set
- Session words are filtered from diagnostics (in `check_buffer_diagnostics`)

### `lua/nvim-spell.lua` — Public API

- `setup(opts)` — merges config, validates cspell availability, sets up autocmds
- `enable()` / `disable()` — toggles autocmds and diagnostics
- `toggle_plugin()` — flips enable/disable

**Config defaults**:
```lua
cspell_cmd = 'cspell'
config_file = nil            -- path to cspell.json (nil = auto-detect)
check_on_save = true         -- BufWritePost autocmd
check_on_change = false      -- debounced TextChangedI autocmd
check_delay = 500            -- debounce ms
filetypes = nil              -- restrict (nil = all)
diagnostic_severity = vim.diagnostic.severity.INFO
```

## Commands

| Command | Function |
|---------|----------|
| `:SpellSuggest` | Show suggestions via `vim.ui.select`, replace on choice |
| `:SpellNext` / `:SpellPrev` | Jump between diagnostics |
| `:SpellAdd` / `:SpellAdd!` | Add word to session / cspell.json |
| `:SpellCheck` | Run cspell lint and show diagnostics |
| `:SpellCheckBuffer` | Run cspell lint and populate quickfix |
| `:SpellDisable` / `:SpellEnable` | Toggle plugin on/off |
| `:SpellTogglePlugin` | Flip enable/disable |

## Tests

Tests use plenary.nvim's busted-style framework. `tests/minimal_init.lua` bootstraps plenary (clones to `/tmp/plenary.nvim` if missing).

- `tests/nvim-spell/nvim-spell_spec.lua` — setup, config, enable/disable
- `tests/nvim-spell/bug_fixes_spec.lua` — word replacement, suggestions, navigation
- `tests/nvim-spell/cspell_spec.lua` — cspell CLI: find_config, parse_lint_output, get_suggestions, add_word, run_lint
