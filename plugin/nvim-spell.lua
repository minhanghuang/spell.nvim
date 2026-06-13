vim.api.nvim_create_user_command('SpellSuggest', function()
  require('nvim-spell.module').suggest_and_replace_current()
end, { desc = 'Show suggestions for the word under cursor and optionally replace it' })

vim.api.nvim_create_user_command('SpellNext', function()
  require('nvim-spell.module').goto_next_misspelled()
end, { desc = 'Jump to next misspelled word' })

vim.api.nvim_create_user_command('SpellPrev', function()
  require('nvim-spell.module').goto_prev_misspelled()
end, { desc = 'Jump to previous misspelled word' })

vim.api.nvim_create_user_command('SpellAdd', function(opts)
  -- Supports bang: :SpellAdd or :SpellAdd!
  require('nvim-spell.module').add_current_word(opts.bang)
end, { bang = true, desc = 'Add current word to cspell config (use ! to persist)' })

vim.api.nvim_create_user_command('SpellCheck', function()
  require('nvim-spell.module').check_buffer_diagnostics()
end, { desc = 'Run cspell on the current buffer and show diagnostics' })

vim.api.nvim_create_user_command('SpellCheckBuffer', function()
  require('nvim-spell.module').check_buffer_to_qf()
end, { desc = 'Run cspell on the current buffer and populate quickfix' })

vim.api.nvim_create_user_command('SpellDisable', function()
  require('nvim-spell').disable()
end, { desc = 'Disable nvim-spell: turn off autocmds and clear diagnostics' })

vim.api.nvim_create_user_command('SpellEnable', function()
  require('nvim-spell').enable()
end, { desc = 'Enable nvim-spell: restore autocmds and check' })

vim.api.nvim_create_user_command('SpellTogglePlugin', function()
  require('nvim-spell').toggle_plugin()
end, { desc = 'Toggle nvim-spell enable/disable (plugin-level)' })
