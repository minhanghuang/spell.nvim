-- main module file for nvim-spell
local module = require("nvim-spell.module")

---@class Config
---@field opt string Your config option
---@field enabled boolean|nil Whether to enable `vim.opt.spell` during setup
---@field spellfile string|table|nil Path (or list) to spellfile to use for persistent words
local config = {
  opt = "Hello!",
  enabled = nil,
  spelllang = nil,
  -- spellfile: path or list of paths to use for persistent additions
  -- default: stdpath('config') .. '/spell/custom.en.utf-8.add'
  spellfile = nil,
}

---@class MyModule
local M = {}

---@type Config
M.config = config

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

  -- Note: keymap configuration removed. Use commands to interact with plugin.
end

M.hello = function()
  return module.my_first_function(M.config.opt)
end

--- Disable plugin behaviour: turn off spell and remove configured keymaps
M.disable = function()
  vim.opt.spell = false
  -- Keymaps are not managed by the plugin anymore; plugin is command-driven.
  vim.notify('nvim-spell disabled', vim.log.levels.INFO)
end

--- Enable plugin behaviour: re-apply setup (re-register keymaps and spell)
M.enable = function()
  -- Re-run setup with current config to restore keymaps and spell settings
  M.setup({})
  vim.notify('nvim-spell enabled', vim.log.levels.INFO)
end

--- Toggle plugin enable/disable (plugin-level toggle)
M.toggle_plugin = function()
  if vim.opt.spell:get() then
    M.disable()
  else
    M.enable()
  end
end

return M
