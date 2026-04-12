-- main module file for nvim-spell
local module = require("nvim-spell.module")

---@class Config
---@field opt string Your config option
---@field enabled boolean|nil Whether to enable `vim.opt.spell` during setup
---@field spellfile string|table|nil Path (or list) to spellfile to use for persistent words
---@field exclude_filetypes table|nil List of filetypes to exclude from spell checking
local config = {
  opt = "Hello!",
  enabled = nil,
  spelllang = nil,
  -- spellfile: path or list of paths to use for persistent additions
  -- default: stdpath('config') .. '/spell/custom.en.utf-8.add'
  spellfile = nil,
  -- Filetypes to exclude from spell checking (in addition to defaults)
  exclude_filetypes = nil,
}

-- Plugin-level state tracking
local plugin_state = {
  -- Track whether spell checking is globally enabled by the plugin
  spell_enabled = nil,
  -- Autocommand group ID for managing spell state
  augroup = nil,
}

---@class MyModule
local M = {}

---@type Config
M.config = config

--- Check if a window should be excluded from spell checking
--- @param win number Window handle
--- @return boolean
local function should_exclude_window(win)
  if not vim.api.nvim_win_is_valid(win) then
    return true
  end

  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.api.nvim_buf_is_valid(buf) then
    return true
  end

  -- Get buffer properties
  local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
  local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')

  -- Exclude special buffer types
  local excluded_buftypes = {
    'nofile',
    'terminal',
    'prompt',
    'quickfix',
    'help',
  }

  for _, bt in ipairs(excluded_buftypes) do
    if buftype == bt then
      return true
    end
  end

  -- Exclude file tree and other special filetypes
  local excluded_filetypes = {
    'NvimTree',
    'nvim-tree',
    'neo-tree',
    'nerdtree',
    'CHADTree',
    'fern',
    'fugitive',
    'gitcommit',
    'qf',
    'help',
    'man',
    'lspinfo',
    'TelescopePrompt',
    'alpha',
    'dashboard',
    'aerial',
    'Outline',
    'Trouble',
    'toggleterm',
  }

  -- Add user-configured exclusions
  if M.config.exclude_filetypes then
    for _, ft in ipairs(M.config.exclude_filetypes) do
      table.insert(excluded_filetypes, ft)
    end
  end

  for _, ft in ipairs(excluded_filetypes) do
    if filetype == ft then
      return true
    end
  end

  return false
end

--- Apply spell setting to all windows
---@param enabled boolean
local function apply_spell_to_all_windows(enabled)
  -- Apply to all existing windows, excluding special ones
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if should_exclude_window(win) then
      -- Explicitly disable spell for excluded windows
      vim.api.nvim_win_set_option(win, 'spell', false)
    else
      vim.api.nvim_win_set_option(win, 'spell', enabled)
    end
  end
end

--- Setup autocommand to apply spell state to new windows
local function setup_spell_autocommand()
  if plugin_state.augroup then
    -- Clear existing autocommands
    vim.api.nvim_del_augroup_by_id(plugin_state.augroup)
  end

  -- Create autocommand group
  plugin_state.augroup = vim.api.nvim_create_augroup('NvimSpellSync', { clear = true })

  -- Apply spell state to new windows/buffers
  vim.api.nvim_create_autocmd({ 'WinNew', 'BufWinEnter' }, {
    group = plugin_state.augroup,
    callback = function()
      if plugin_state.spell_enabled ~= nil then
        local win = vim.api.nvim_get_current_win()
        -- Only apply to non-excluded windows
        if not should_exclude_window(win) then
          vim.wo.spell = plugin_state.spell_enabled
        end
      end
    end,
    desc = 'Sync spell state to new windows',
  })
end

---@param args Config?
-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})

  -- Apply spell configuration if provided by the user.
  -- Example usage:
  -- require('nvim-spell').setup({ enabled = true, spelllang = { 'en_us' } })
  if M.config.enabled ~= nil then
    vim.opt.spell = M.config.enabled
  end

  if M.config.spelllang ~= nil then
    vim.opt.spelllang = M.config.spelllang
  end

  -- Ensure a default persistent spellfile exists if not provided
  local spellfile = M.config.spellfile
  if not spellfile then
    local cfg = vim.fn.stdpath('config')
    local spelldir = cfg .. '/spell'
    if vim.fn.isdirectory(spelldir) == 0 then
      vim.fn.mkdir(spelldir, 'p')
    end
    spellfile = spelldir .. '/custom.en.utf-8.add'
  end
  vim.opt.spellfile = spellfile

  -- Ensure spellfile(s) exist: create parent dirs and empty files if necessary
  local function ensure_spellfiles(pathval)
    local s = pathval or vim.o.spellfile
    if not s or s == '' then return end
    for p in string.gmatch(s, '([^,]+)') do
      local expanded = vim.fn.expand(p)
      local dir = vim.fn.fnamemodify(expanded, ':h')
      if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, 'p')
      end
      if vim.fn.filereadable(expanded) == 0 then
        vim.fn.writefile({}, expanded)
      end
    end
  end
  pcall(function() ensure_spellfiles(spellfile) end)

  -- Initialize plugin state tracking
  if M.config.enabled ~= nil then
    plugin_state.spell_enabled = M.config.enabled
  end

  -- Setup autocommand to sync spell state across all new windows
  setup_spell_autocommand()

  -- Note: keymap configuration removed. Use commands to interact with plugin.
end

M.hello = function()
  return module.my_first_function(M.config.opt)
end

--- Disable plugin behaviour: turn off spell in all windows
M.disable = function()
  plugin_state.spell_enabled = false
  apply_spell_to_all_windows(false)
  vim.notify('nvim-spell disabled (all windows)', vim.log.levels.INFO)
end

--- Enable plugin behaviour: re-apply setup (re-register keymaps and spell)
M.enable = function()
  plugin_state.spell_enabled = true

  -- Re-apply config settings
  if M.config.enabled ~= nil then
    apply_spell_to_all_windows(M.config.enabled)
  else
    apply_spell_to_all_windows(true)
  end

  if M.config.spelllang ~= nil then
    vim.opt.spelllang = M.config.spelllang
  end

  vim.notify('nvim-spell enabled (all windows)', vim.log.levels.INFO)
end

--- Toggle plugin enable/disable (plugin-level toggle)
M.toggle_plugin = function()
  -- Check the plugin state instead of just current window
  if plugin_state.spell_enabled == false then
    M.enable()
  else
    M.disable()
  end
end

return M
