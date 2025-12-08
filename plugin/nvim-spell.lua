vim.api.nvim_create_user_command("MyFirstFunction", require("nvim-spell").hello, {})
vim.api.nvim_create_user_command("SpellSuggest", function()
  require("nvim-spell.module").suggest_and_replace_current()
end, { desc = "Show suggestions for the word under cursor and optionally replace it" })

vim.api.nvim_create_user_command("SpellNext", function()
  require("nvim-spell.module").goto_next_misspelled()
end, { desc = "Jump to next misspelled word" })

vim.api.nvim_create_user_command("SpellPrev", function()
  require("nvim-spell.module").goto_prev_misspelled()
end, { desc = "Jump to previous misspelled word" })


vim.api.nvim_create_user_command("SpellAdd", function(opts)
  -- supports bang: :SpellAdd or :SpellAdd!
  require("nvim-spell.module").add_current_word(opts.bang)
end, { bang = true, desc = "Add current word to spellgood (use ! to persist)" })

-- `:SpellCheckWord`, `:SpellToggle`, and `:SpellCheckBuffer` have been removed.

-- Use `:SpellAdd!` to persist words into the configured spellfile (default: $XDG_CONFIG_HOME/nvim/spell/custom.en.utf-8.add).
vim.api.nvim_create_user_command("SpellDisable", function()
  require('nvim-spell').disable()
end, { desc = "Disable nvim-spell: turn off spell and remove keymaps" })

vim.api.nvim_create_user_command("SpellEnable", function()
  require('nvim-spell').enable()
end, { desc = "Enable nvim-spell: restore keymaps and spell setting" })

vim.api.nvim_create_user_command("SpellTogglePlugin", function()
  require('nvim-spell').toggle_plugin()
end, { desc = "Toggle nvim-spell enable/disable (plugin-level)" })
