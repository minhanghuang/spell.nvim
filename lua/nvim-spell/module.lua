---@class SpellModule
---Core spell-checking logic built on top of the cspell CLI.
local M = {}

local cspell = require("nvim-spell.cspell")

---@type integer Diagnostic namespace for nvim-spell
M.diagnostic_namespace = vim.api.nvim_create_namespace("nvim-spell")

---Get the word currently under the cursor.
---@return string|nil
local function _current_word()
  return vim.fn.expand("<cword>")
end

---Get the cspell command from plugin config (falls back to 'cspell').
---@return string
local function _get_cspell_cmd()
  local ok, plugin = pcall(require, "nvim-spell")
  if ok and plugin.config and plugin.config.cspell_cmd then
    return plugin.config.cspell_cmd
  end
  return "cspell"
end

---Get the cspell config path for the current buffer.
---First checks plugin config, then searches project directories, then falls back to
---a global config in stdpath('config')/spell/.
---@param buf integer|nil
---@return string|nil
local function _get_config_path(buf)
  local ok, plugin = pcall(require, "nvim-spell")
  if ok and plugin.config and plugin.config.config_file then
    local expanded = vim.fn.expand(plugin.config.config_file)
    if vim.fn.filereadable(expanded) == 1 then
      return expanded
    end
  end

  buf = buf or vim.api.nvim_get_current_buf()
  local found = cspell.find_config(buf)
  if found then
    return found
  end

  -- Fallback: global config in Neovim's config directory
  local global = vim.fn.stdpath("config") .. "/spell/cspell.json"
  if vim.fn.filereadable(global) == 1 then
    return global
  end

  return nil
end

---Get the locale from plugin config.
---@return string|nil
local function _get_locale()
  local ok, plugin = pcall(require, "nvim-spell")
  if ok and plugin.config and plugin.config.locale then
    return plugin.config.locale
  end
  return nil
end

---Get the dictionaries from plugin config.
---@return table
local function _get_dictionaries()
  local ok, plugin = pcall(require, "nvim-spell")
  if ok and plugin.config and plugin.config.dictionaries then
    return plugin.config.dictionaries
  end
  return {}
end

---Get the default directory for creating a new cspell config.
---If the buffer has a file path, use its project directory.
---Otherwise, fall back to stdpath('config')/spell/.
---@param buf integer
---@return string
local function _get_default_config_dir(buf)
  local bufname = vim.api.nvim_buf_get_name(buf)
  if bufname ~= "" then
    local dir = vim.fn.fnamemodify(bufname, ":h")
    if vim.fn.isdirectory(dir) == 1 then
      return dir
    end
  end
  -- Fallback: Neovim config spell directory
  local spelldir = vim.fn.stdpath("config") .. "/spell"
  if vim.fn.isdirectory(spelldir) == 0 then
    vim.fn.mkdir(spelldir, "p")
  end
  return spelldir
end

---Run diagnostics on a buffer and set them via `vim.diagnostic.set`.
---@param buf integer|nil Buffer handle (default: current)
M.check_buffer_diagnostics = function(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  -- Skip if buffer is not a file or is empty
  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count == 0 then
    return
  end

  local cmd = _get_cspell_cmd()
  if not cspell.is_cspell_available(cmd) then
    vim.notify("[nvim-spell] cspell not found. Install: npm install -g cspell", vim.log.levels.WARN)
    return
  end

  local config_path = _get_config_path(buf)
  local bufnr = buf

  cspell.run_lint(buf, config_path, function(issues, err)
    if err then
      vim.schedule(function()
        vim.notify("[nvim-spell] " .. err, vim.log.levels.ERROR)
      end)
      return
    end

    vim.schedule(function()
      -- Validate buffer still exists
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      if not issues or #issues == 0 then
        -- Clear diagnostics for this buffer
        vim.diagnostic.set(M.diagnostic_namespace, bufnr, {})
        return
      end

      -- Get severity from config
      local severity = vim.diagnostic.severity.INFO
      local ok, plugin = pcall(require, "nvim-spell")
      if ok and plugin.config and plugin.config.diagnostic_severity then
        severity = plugin.config.diagnostic_severity
      end

      -- Filter out session words
      local session_words = M._session_words or {}

      ---@type vim.Diagnostic[]
      local diagnostics = {}
      for _, issue in ipairs(issues) do
        if not session_words[issue.text] then
          table.insert(diagnostics, {
            lnum = issue.lnum,
            col = issue.col,
            end_col = issue.end_col,
            message = 'Misspelled: "' .. issue.text .. '"',
            severity = severity,
            source = "cspell",
            user_data = {
              suggestions = issue.suggestions,
              text = issue.text,
            },
          })
        end
      end

      vim.diagnostic.set(M.diagnostic_namespace, bufnr, diagnostics)
    end)
  end, cmd, _get_locale(), _get_dictionaries())
end

---Run diagnostics and populate the quickfix list.
M.check_buffer_to_qf = function()
  local buf = vim.api.nvim_get_current_buf()
  local cmd = _get_cspell_cmd()

  if not cspell.is_cspell_available(cmd) then
    vim.notify("[nvim-spell] cspell not found. Install: npm install -g cspell", vim.log.levels.WARN)
    return
  end

  local config_path = _get_config_path(buf)
  local name = vim.api.nvim_buf_get_name(buf)

  cspell.run_lint(buf, config_path, function(issues, err)
    if err then
      vim.schedule(function()
        vim.notify("[nvim-spell] " .. err, vim.log.levels.ERROR)
      end)
      return
    end

    vim.schedule(function()
      if not issues or #issues == 0 then
        vim.notify("No misspelled words found in buffer", vim.log.levels.INFO)
        return
      end

      local qflist = {}
      for _, issue in ipairs(issues) do
        table.insert(qflist, {
          filename = name,
          lnum = issue.lnum + 1, -- quickfix uses 1-indexed lines
          col = issue.col + 1, -- quickfix uses 1-indexed columns
          text = issue.text,
        })
      end

      vim.fn.setqflist(qflist, "r")
      vim.cmd("copen")
      vim.notify("Found " .. tostring(#qflist) .. " misspellings — quickfix opened", vim.log.levels.INFO)
    end)
  end, _get_cspell_cmd(), _get_locale())
end

---Check a single word for misspelling.
---@param word string|nil
---@return table { ok: boolean, message: string, suggestions: string[] }
M.check_word = function(word)
  word = word or _current_word()
  if not word or word == "" then
    return { ok = true, message = "no word", suggestions = {} }
  end

  local cmd = _get_cspell_cmd()
  if not cspell.is_cspell_available(cmd) then
    return { ok = true, message = "cspell not available", suggestions = {} }
  end

  local config_path = _get_config_path()
  local suggestions = cspell.get_suggestions(word, config_path, cmd, _get_locale(), _get_dictionaries())

  -- cspell suggestions always returns the input word as the first suggestion
  -- if the word is found in the dictionary (followed by variations).
  -- For misspelled words, the first suggestion is a correction (different from input).
  if #suggestions > 0 then
    local is_correct = (suggestions[1] == word)
    if is_correct then
      return {
        ok = true,
        message = string.format("'%s' is spelled correctly", word),
        suggestions = {},
      }
    else
      return {
        ok = false,
        message = string.format("'%s' may be misspelled", word),
        suggestions = suggestions,
      }
    end
  end

  -- No suggestions at all — word not in dictionary and no alternatives found
  return {
    ok = false,
    message = string.format("'%s' not found in dictionary (no suggestions)", word),
    suggestions = {},
  }
end

---Check the current word under cursor and notify the user.
M.check_current_word = function()
  local word = _current_word()
  if not word or word == "" then
    vim.notify("No word under cursor to check", vim.log.levels.INFO)
    return
  end

  local result = M.check_word(word)
  if result.ok then
    vim.notify(result.message, vim.log.levels.INFO)
  else
    if #result.suggestions == 0 then
      vim.notify(result.message .. ": no suggestions", vim.log.levels.WARN)
    else
      -- Show first 10 suggestions
      local show = {}
      for i = 1, math.min(#result.suggestions, 10) do
        table.insert(show, result.suggestions[i])
      end
      vim.notify(result.message .. ": " .. table.concat(show, ", "), vim.log.levels.WARN)
    end
  end
end

---Replace the word under cursor with `replacement`.
---Uses `viw` visual selection to get accurate word boundaries, then `nvim_buf_set_text`.
---@param replacement string
M.replace_current_word = function(replacement)
  if not replacement or replacement == "" then
    return
  end

  -- Save cursor position
  local save_cursor = vim.fn.getpos(".")

  -- Use viw to select the inner word and get its boundaries
  vim.cmd("normal! viw")
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")

  -- Restore cursor
  vim.fn.setpos(".", save_cursor)

  -- nvim_buf_set_text uses 0-indexed [row, col)
  local row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_col = end_pos[3]

  -- end_col from getpos('.') is the column just past the last character of the visual selection
  -- when selection is forward. If the visual selection goes backward, swap.
  if end_col < start_col then
    start_col, end_col = end_col, start_col
  end

  vim.api.nvim_buf_set_text(0, row, start_col, row, end_col, { replacement })
end

---Show spelling suggestions for the word under cursor and optionally replace it.
M.suggest_and_replace_current = function()
  local word = _current_word()
  if not word or word == "" then
    vim.notify("No word under cursor", vim.log.levels.INFO)
    return
  end

  local cmd = _get_cspell_cmd()
  if not cspell.is_cspell_available(cmd) then
    vim.notify("[nvim-spell] cspell not found. Install: npm install -g cspell", vim.log.levels.WARN)
    return
  end

  local config_path = _get_config_path()
  local suggestions = cspell.get_suggestions(word, config_path, cmd, _get_locale(), _get_dictionaries())

  if #suggestions == 0 then
    vim.notify("No suggestions for: " .. word, vim.log.levels.INFO)
    return
  end

  -- Try to also include suggestions from diagnostics at cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local diags = vim.diagnostic.get(0, {
    namespace = M.diagnostic_namespace,
    lnum = cursor[1] - 1,
  })

  -- Merge suggestions from cspell suggestions command with those from diagnostics
  local suggestion_set = {}
  local ordered = {}
  for _, s in ipairs(suggestions) do
    if not suggestion_set[s] then
      suggestion_set[s] = true
      table.insert(ordered, s)
    end
  end

  -- Also check diagnostics for additional suggestions
  for _, d in ipairs(diags) do
    if d.user_data and d.user_data.suggestions then
      for _, s in ipairs(d.user_data.suggestions) do
        if not suggestion_set[s] then
          suggestion_set[s] = true
          table.insert(ordered, s)
        end
      end
    end
  end

  if vim.ui and vim.ui.select then
    vim.ui.select(ordered, { prompt = 'Replace "' .. word .. '" with:' }, function(choice)
      if choice then
        M.replace_current_word(choice)
      end
    end)
  else
    -- Fallback: notify with first few suggestions
    local show = {}
    for i = 1, math.min(#ordered, 5) do
      table.insert(show, ordered[i])
    end
    vim.notify("Suggestions: " .. table.concat(show, ", "), vim.log.levels.INFO)
  end
end

---Jump to next misspelled word (diagnostic).
M.goto_next_misspelled = function()
  vim.diagnostic.goto_next({ namespace = M.diagnostic_namespace })
end

---Jump to previous misspelled word (diagnostic).
M.goto_prev_misspelled = function()
  vim.diagnostic.goto_prev({ namespace = M.diagnostic_namespace })
end

---Add the word under cursor to the cspell config file.
---If `persist` is true, add to cspell.json. Otherwise, add to session-only ignore list.
---@param persist boolean|nil If true (bang), persist to config file
M.add_current_word = function(persist)
  local word = _current_word()
  if not word or word == "" then
    vim.notify("No word under cursor", vim.log.levels.INFO)
    return
  end

  if persist then
    -- Persist to cspell.json
    local cmd = _get_cspell_cmd()
    if not cspell.is_cspell_available(cmd) then
      vim.notify("[nvim-spell] cspell not found. Install: npm install -g cspell", vim.log.levels.WARN)
      return
    end

    local buf = vim.api.nvim_get_current_buf()
    local config_path = _get_config_path(buf)

    -- If no config found, create one (project dir or stdpath('config')/spell/)
    if not config_path then
      local dir = _get_default_config_dir(buf)
      config_path = cspell.ensure_config(dir, cmd, _get_locale(), _get_dictionaries())
      if not config_path then
        return
      end
    end

    -- Add word to config
    cspell.add_word(word, config_path)

    -- Re-run lint to update diagnostics
    M.check_buffer_diagnostics()
  else
    -- Session-only: use vim.diagnostic to hide this word's diagnostics
    -- Check if word is already in a config file (if so, it won't be flagged anyway)
    local config_path = _get_config_path()
    if config_path and cspell.word_in_config(word, config_path) then
      vim.notify('"' .. word .. '" is already in cspell config', vim.log.levels.INFO)
      return
    end

    -- For session-only, we mark it in an in-memory set
    M._session_words = M._session_words or {}
    M._session_words[word] = true
    vim.notify('Marked "' .. word .. '" as correct for this session', vim.log.levels.INFO)

    -- Re-run diagnostics (the session words filter is in check_buffer_diagnostics)
    M.check_buffer_diagnostics()
  end
end

---Check whether a word has been marked as correct in the current session.
---@param word string
---@return boolean
M.is_session_word = function(word)
  if not M._session_words then
    return false
  end
  return M._session_words[word] == true
end

return M
