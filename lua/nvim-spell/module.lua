---@class CustomModule
local M = {}

---@return string
M.my_first_function = function(greeting)
  return greeting
end

local function _current_word()
  return vim.fn.expand("<cword>")
end

local function _contains_cjk(word)
  if not word or word == "" then
    return false
  end
  -- Check for CJK characters: Chinese (一-龥), Japanese Hiragana (぀-ゟ),
  -- Katakana (ァ-ヿ), Korean Hangul (가-힣), and common CJK symbols
  -- vim.fn.match returns -1 when no match
  return vim.fn.match(word, '[一-龥぀-ゟァ-ヿ가-힣]') ~= -1
end

--- Ensure all configured spellfiles exist (create directories and empty files if needed)
local function _ensure_spellfiles()
  local s = vim.o.spellfile or ''
  if s == '' then return end
  for path in string.gmatch(s, '([^,]+)') do
    local p = vim.fn.expand(path)
    local dir = vim.fn.fnamemodify(p, ':h')
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, 'p')
    end
    if vim.fn.filereadable(p) == 0 then
      vim.fn.writefile({}, p)
    end
  end
end

-- ignore list (as a set for fast lookup)
-- No in-memory ignore list; persistent ignored words should be added to the spellfile
-- using `:spellgood!` (see `:SpellAdd` with bang) so they persist in the spellfile.

--- Check whether a word is misspelled using Neovim/Vim built-in spell
--- If called without args, checks the word under the cursor and notifies the user.
--- @param word string|nil
M.check_word = function(word)
  word = word or _current_word()
  if word == nil or word == "" then
    return {
      ok = true,
      message = "no word",
      suggestions = {},
    }
  end

  if _contains_cjk(word) then
    return { ok = true, message = "contains CJK — skipped", suggestions = {} }
  end

  local bad = vim.fn.spellbadword(word)
  local misspelled = false
  if type(bad) == "table" then
    misspelled = (bad[1] ~= "")
  else
    misspelled = (bad ~= "")
  end

  local res = { ok = not misspelled, message = "", suggestions = {} }
  if not misspelled then
    res.message = string.format("'%s' is spelled correctly", word)
    return res
  end

  local suggestions = vim.fn.spellsuggest(word, 10)
  if type(suggestions) == "table" then
    res.suggestions = suggestions
  end
  res.message = string.format("'%s' may be misspelled", word)
  return res
end

--- Check the current word under cursor and notify user with suggestions
M.check_current_word = function()
  local word = _current_word()
  if word == nil or word == "" then
    vim.notify("No word under cursor to check", vim.log.levels.INFO)
    return
  end

  if _contains_cjk(word) then
    vim.notify("Word contains CJK characters — skipping spell check", vim.log.levels.INFO)
    return
  end

  local result = M.check_word(word)
  if result.ok then
    vim.notify(result.message, vim.log.levels.INFO)
  else
    if next(result.suggestions) == nil then
      vim.notify(result.message .. ": no suggestions", vim.log.levels.WARN)
    else
      vim.notify(result.message .. ": " .. table.concat(result.suggestions, ", "), vim.log.levels.WARN)
    end
  end
end

--- Replace the current word under cursor with `replacement`.
--- @param replacement string
M.replace_current_word = function(replacement)
  if not replacement or replacement == "" then
    return
  end
  -- Use getpos to get accurate word boundaries
  local save_cursor = vim.fn.getpos('.')
  vim.cmd('normal! viw')  -- visually select inner word
  local start_pos = vim.fn.getpos('v')
  local end_pos = vim.fn.getpos('.')
  vim.fn.setpos('.', save_cursor)  -- restore cursor

  -- nvim_buf_set_text uses 0-indexed positions
  local row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_col = end_pos[3]

  vim.api.nvim_buf_set_text(0, row, start_col, row, end_col, { replacement })
end

--- Show suggestions for current word and optionally replace it.
M.suggest_and_replace_current = function()
  local word = _current_word()
  if not word or word == "" then
    vim.notify("No word under cursor to suggest for", vim.log.levels.INFO)
    return
  end

  if _contains_cjk(word) then
    vim.notify("Word contains CJK characters — skipping suggestions", vim.log.levels.INFO)
    return
  end

  local suggestions = vim.fn.spellsuggest(word, 20)
  if not suggestions or vim.tbl_isempty(suggestions) then
    vim.notify("No suggestions found for: " .. word, vim.log.levels.WARN)
    return
  end

  if vim.ui and vim.ui.select then
    vim.ui.select(suggestions, { prompt = 'Replace "' .. word .. '" with:' }, function(choice)
      if choice then
        M.replace_current_word(choice)
      end
    end)
  else
    -- fallback: notify the first few suggestions
    vim.notify("Suggestions: " .. table.concat(vim.list_slice(suggestions, 1, 5), ", "), vim.log.levels.INFO)
  end
end

--- Jump to next misspelled word (uses built-in ]s motion)
M.goto_next_misspelled = function()
  vim.cmd('normal! ]s')
end

--- Jump to previous misspelled word (uses built-in [s motion)
M.goto_prev_misspelled = function()
  vim.cmd('normal! [s')
end

--- Toggle `vim.opt.spell` and notify the user
M.toggle_spell = function()
  vim.opt.spell = not vim.opt.spell:get()
  vim.notify("spell set to " .. tostring(vim.opt.spell:get()), vim.log.levels.INFO)
end

--- Add current word to the spellgood list. If `persist` is true (bang), add persistently.
---@param persist boolean|nil
M.add_current_word = function(persist)
  local word = _current_word()
  if not word or word == "" then
    vim.notify("No word under cursor to add", vim.log.levels.INFO)
    return
  end
  if _contains_cjk(word) then
    vim.notify("Contains CJK — not adding to dictionary", vim.log.levels.WARN)
    return
  end

  if persist then
    -- Ensure spellfile(s) exist so :spellgood! can write to them
    pcall(_ensure_spellfiles)

    -- Check whether the word already exists in any configured spellfile
    local function word_in_spellfiles(w)
      local s = vim.o.spellfile or ''
      if s == '' then return false end
      for path in string.gmatch(s, '([^,]+)') do
        local p = vim.fn.expand(path)
        if vim.fn.filereadable(p) == 1 then
          local lines = vim.fn.readfile(p)
          for _, ln in ipairs(lines) do
            if ln == w then
              return true
            end
          end
        end
      end
      return false
    end

    if word_in_spellfiles(word) then
      vim.notify('"' .. word .. '" already present in spellfile, skipping', vim.log.levels.INFO)
    else
      -- run silently to avoid "Press ENTER" prompts from Vim messages
      pcall(vim.cmd, 'silent! spellgood! ' .. word)
      vim.notify('Added "' .. word .. '" persistently to spellfile', vim.log.levels.INFO)
    end
  else
    -- mark for this session silently
    pcall(vim.cmd, 'silent! spellgood ' .. word)
    vim.notify('Marked "' .. word .. '" as correct for this session', vim.log.levels.INFO)
  end
end

--- Add a word to the ignore list (in-memory)
---@param word string
-- ignore-list functions removed: use `:SpellAdd!` to persist words into the configured spellfile.

--- Scan the current buffer for misspelled words and populate the quickfix list.
M.check_buffer_to_qf = function()
  local qflist = {}
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    -- Extract words from line: gmatch returns (start_pos, word_text, end_pos)
    for start_pos, word_text, end_pos in line:gmatch('()(%w+)()') do
      if not _contains_cjk(word_text) then
        local bad = vim.fn.spellbadword(word_text)
        local miss = false
        if type(bad) == 'table' then
          miss = (bad[1] ~= '')
        else
          miss = (bad ~= '')
        end
        if miss then
          table.insert(qflist, {
            filename = name,
            lnum = i,
            col = start_pos,
            text = word_text
          })
        end
      end
    end
  end
  if vim.tbl_isempty(qflist) then
    vim.notify('No misspelled words found in buffer', vim.log.levels.INFO)
    return
  end
  vim.fn.setqflist(qflist, 'r')
  vim.cmd('copen')
  vim.notify('Found ' .. tostring(#qflist) .. ' misspellings — quickfix opened', vim.log.levels.INFO)
end

return M
