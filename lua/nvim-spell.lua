---@class nvim-spell.Config
---@field cspell_cmd string Path to cspell binary (default: 'cspell')
---@field config_file string|nil Path to cspell config file (nil = auto-detect)
---@field locale string|nil Language locale(s) e.g. "en,zh-cn" or "en-US,de" (nil = cspell default)
---@field check_on_save boolean Run spell check on BufWritePost (default: true)
---@field check_on_change boolean Run debounced spell check on TextChangedI (default: false)
---@field check_delay integer Debounce delay in ms for check_on_change (default: 500)
---@field filetypes table|nil Filetypes to attach to (nil = all, unless excluded)
---@field exclude_filetypes table|nil Filetypes to exclude (default: file explorers, help, qf, etc.)
---@field dictionaries table|nil cspell dictionaries to enable, e.g. {'lua', 'bash', 'softwareTerms'}
---@field diagnostic_severity integer Diagnostic severity level (default: INFO)

-- Filetypes that are never spell-checked (file explorers, special buffers, etc.)
local DEFAULT_EXCLUDE = {
  "neo-tree",
  "NvimTree",
  "nvimtree",
  "nerdtree",
  "NERDTree",
  "netrw",
  "oil",
  "fern",
  "dirvish",
  "help",
  "qf",
  "checkhealth",
  "lspinfo",
  "mason",
  "lazy",
  "TelescopePrompt",
  "fzf",
  "noice",
  "notify",
  "lir",
  "DiffviewFiles",
}

---@type nvim-spell.Config
local config = {
  cspell_cmd = "cspell",
  config_file = nil,
  locale = nil,
  check_on_save = true,
  check_on_change = false,
  check_delay = 500,
  filetypes = nil,
  exclude_filetypes = DEFAULT_EXCLUDE,
  dictionaries = { "en_us", "lua", "bash", "softwareTerms" },
  diagnostic_severity = vim.diagnostic.severity.INFO,
}

---@class nvim-spell.Plugin
local M = {}

---@type nvim-spell.Config
M.config = config

---@type integer|nil Augroup ID for nvim-spell autocmds
M._augroup = nil

---@type table|nil Debounce timers per buffer (for check_on_change)
M._timers = {}

---Setup the plugin with user configuration.
---@param args nvim-spell.Config?
M.setup = function(args)
  if args then
    for k, v in pairs(args) do
      M.config[k] = v
    end
  end

  -- Resolve cspell binary path (PATH first, then mason.nvim fallback)
  local cspell_mod = require("nvim-spell.cspell")
  M.config.cspell_cmd = cspell_mod.resolve_cspell_path(M.config.cspell_cmd)

  -- Validate cspell availability (non-blocking check)
  if not cspell_mod.is_cspell_available(M.config.cspell_cmd) then
    vim.schedule(function()
      vim.notify(
        "[nvim-spell] cspell not found. Install via: npm install -g cspell, or :MasonInstall cspell",
        vim.log.levels.WARN
      )
    end)
  end

  -- Auto-create config file on first use if none exists
  local existing = M.config.config_file
      and vim.fn.filereadable(vim.fn.expand(M.config.config_file)) == 1
      and vim.fn.expand(M.config.config_file)
    or cspell_mod.find_config()
    or (function()
      local p = vim.fn.stdpath("config") .. "/spell/cspell.json"
      return vim.fn.filereadable(p) == 1 and p or nil
    end)()

  if not existing then
    local spelldir = vim.fn.stdpath("config") .. "/spell"
    if vim.fn.isdirectory(spelldir) == 0 then
      vim.fn.mkdir(spelldir, "p")
    end
    cspell_mod.ensure_config(spelldir, M.config.cspell_cmd, M.config.locale, M.config.dictionaries)
  end

  -- Set up autocmds
  M._enable_autocmds()
end

---Create autocmds for automatic spell checking.
---@private
M._enable_autocmds = function()
  -- Clear existing group
  if M._augroup then
    pcall(vim.api.nvim_del_augroup_by_id, M._augroup)
  end

  M._augroup = vim.api.nvim_create_augroup("NvimSpell", { clear = true })

  local module = require("nvim-spell.module")

  -- On save
  if M.config.check_on_save then
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = M._augroup,
      desc = "nvim-spell: check buffer on save",
      callback = function(args)
        if M._should_check_buffer(args.buf) then
          module.check_buffer_diagnostics(args.buf)
        end
      end,
    })
  end

  -- Debounced check on text change
  if M.config.check_on_change then
    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
      group = M._augroup,
      desc = "nvim-spell: check buffer on change (debounced)",
      callback = function(args)
        if not M._should_check_buffer(args.buf) then
          return
        end

        local bufnr = args.buf
        if M._timers[bufnr] then
          M._timers[bufnr]:stop()
          M._timers[bufnr]:close()
        end

        local timer = vim.uv.new_timer()
        if timer then
          M._timers[bufnr] = timer
          timer:start(M.config.check_delay, 0, function()
            timer:stop()
            timer:close()
            M._timers[bufnr] = nil
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(bufnr) then
                module.check_buffer_diagnostics(bufnr)
              end
            end)
          end)
        end
      end,
    })
  end

  -- Clean up timers when buffer is unloaded
  vim.api.nvim_create_autocmd("BufUnload", {
    group = M._augroup,
    desc = "nvim-spell: clean up timers on buf unload",
    callback = function(args)
      if M._timers[args.buf] then
        M._timers[args.buf]:stop()
        M._timers[args.buf]:close()
        M._timers[args.buf] = nil
      end
    end,
  })

  -- Check current buffer on BufEnter if not yet checked
  vim.api.nvim_create_autocmd("BufEnter", {
    group = M._augroup,
    desc = "nvim-spell: check buffer on enter",
    callback = function(args)
      if M._should_check_buffer(args.buf) then
        local existing = vim.diagnostic.get(args.buf, {
          namespace = require("nvim-spell.module").diagnostic_namespace,
        })
        if #existing == 0 then
          module.check_buffer_diagnostics(args.buf)
        end
      end
    end,
  })
end

---Check whether a buffer should be spell-checked (filetype filter + exclude list).
---@param buf integer
---@return boolean
M._should_check_buffer = function(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })

  -- Normalize to table (support both string and table)
  local exclude = M.config.exclude_filetypes
  if type(exclude) == "string" then
    exclude = { exclude }
  end

  -- Check exclude list first (file explorers, special buffers, etc.)
  if exclude and #exclude > 0 then
    if vim.tbl_contains(exclude, ft) then
      return false
    end
  end

  -- Normalize allowlist
  local allow = M.config.filetypes
  if type(allow) == "string" then
    allow = { allow }
  end

  -- If an allowlist is configured, only check those filetypes
  if allow and #allow > 0 then
    return vim.tbl_contains(allow, ft)
  end

  return true
end

---Enable the plugin (create autocmds, check current buffer).
M.enable = function()
  M._enable_autocmds()
  local module = require("nvim-spell.module")
  module.check_buffer_diagnostics(vim.api.nvim_get_current_buf())
  vim.notify("nvim-spell enabled", vim.log.levels.INFO)
end

---Disable the plugin (clear autocmds and diagnostics).
M.disable = function()
  -- Clear autocmds
  if M._augroup then
    pcall(vim.api.nvim_del_augroup_by_id, M._augroup)
    M._augroup = nil
  end

  -- Clear all timers
  for bufnr, timer in pairs(M._timers or {}) do
    timer:stop()
    timer:close()
    M._timers[bufnr] = nil
  end

  -- Clear diagnostics from all buffers
  local module = require("nvim-spell.module")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.diagnostic.set(module.diagnostic_namespace, buf, {})
    end
  end

  vim.notify("nvim-spell disabled", vim.log.levels.INFO)
end

---Toggle the plugin on/off.
M.toggle_plugin = function()
  if M._augroup then
    M.disable()
  else
    M.enable()
  end
end

return M
