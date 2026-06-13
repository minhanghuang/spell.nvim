---@class CSpellIntegration
---Low-level integration with the `cspell` CLI.
---All functions that spawn processes use vim.fn.jobstart for async or vim.fn.system for sync.
local M = {}

---@type string Default cspell binary name
local DEFAULT_CSPELL_CMD = "cspell"

---@type string[] Config file names to search for (in order of preference)
local CONFIG_NAMES =
  { "cspell.json", ".cspell.json", "cspell.yaml", "cspell.yml", "cspell.config.yaml", "cspell.config.yml" }

---Check whether `cspell` is available on PATH.
---@param cmd string|nil
---@return boolean
M.is_cspell_available = function(cmd)
  cmd = cmd or DEFAULT_CSPELL_CMD
  return vim.fn.executable(cmd) == 1
end

---Walk up from a buffer's directory to find a cspell config file.
---@param buf integer|nil Buffer handle (default: current buffer)
---@return string|nil Absolute path to config file, or nil if not found
M.find_config = function(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":h")
  if dir == "" then
    dir = vim.fn.getcwd()
  end

  -- Walk up directories
  local current = vim.fn.resolve(dir)
  local last = nil
  while current ~= last do
    for _, name in ipairs(CONFIG_NAMES) do
      local candidate = current .. "/" .. name
      if vim.fn.filereadable(candidate) == 1 then
        return candidate
      end
    end
    last = current
    current = vim.fn.fnamemodify(current, ":h")
  end

  return nil
end

--- Default words pre-seeded into new cspell configs (common programming & Neovim terms).
local DEFAULT_WORDS = {
  -- Neovim / Lua
  "nvim",
  "neovim",
  "Neovim",
  "lua",
  "Luas",
  "autocmd",
  "autocmds",
  "bufnr",
  "bufname",
  "stdpath",
  "rtp",
  "spelllang",
  "spellfile",
  "spellgood",
  "jobstart",
  "chansend",
  "chanclose",
  "filereadable",
  "getcwd",
  "noplugin",
  -- General programming
  "async",
  "await",
  "api",
  "APIs",
  "config",
  "configs",
  "enum",
  "enums",
  "init",
  "middleware",
  "namespace",
  "repo",
  "repos",
  "src",
  "util",
  "utils",
  -- Web / JS
  "cjs",
  "esm",
  "npm",
  "pnpm",
  "yarn",
  "nodejs",
  "Nodejs",
  "eslint",
  "prettier",
  "ts",
  "tsx",
  "jsx",
  -- CLI / Tools
  "git",
  "github",
  "GitHub",
  "ssh",
  "bash",
  "zsh",
  "docker",
  "Docker",
  "cmake",
  "Makefile",
  -- Common misspellings people add
  "todo",
  "TODO",
  "fixme",
  "FIXME",
}

---Ensure a cspell config file exists at a specific directory.
---Creates one via `cspell init` if the target file does not exist,
---then seeds it with common programming terms.
---@param dir string|nil Directory to create config in (default: cwd)
---@param cmd string|nil cspell binary
---@param locale string|nil Language locale(s) e.g. "en,zh-cn" (nil = cspell default)
---@param dictionaries table|nil Dictionaries to enable, e.g. {'lua', 'bash'}
---@return string|nil Absolute path to created/found config, or nil on failure
M.ensure_config = function(dir, cmd, locale, dictionaries)
  cmd = cmd or DEFAULT_CSPELL_CMD
  dir = dir or vim.fn.getcwd()

  local config_path = dir .. "/cspell.json"

  -- If the target file already exists, just return it
  if vim.fn.filereadable(config_path) == 1 then
    return config_path
  end

  -- Create via cspell init
  local args = { cmd, "init", "-o", config_path, "--format", "json", "--no-comments" }
  if locale and locale ~= "" then
    table.insert(args, "--locale")
    table.insert(args, locale)
  end
  dictionaries = dictionaries or {}
  for _, d in ipairs(dictionaries) do
    table.insert(args, "--dictionary")
    table.insert(args, d)
  end
  local output = vim.fn.system(args)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    vim.notify(string.format("[nvim-spell] Failed to create cspell config: %s", output), vim.log.levels.ERROR)
    return nil
  end

  -- Verify the file was created
  if vim.fn.filereadable(config_path) == 0 then
    vim.notify("[nvim-spell] cspell config was not created: " .. config_path, vim.log.levels.ERROR)
    return nil
  end

  -- Seed with common programming terms
  local lines = vim.fn.readfile(config_path)
  local content = vim.fn.join(lines, "\n")
  local ok, config = pcall(vim.fn.json_decode, content)
  if ok and config then
    config.words = config.words or {}
    local existing = {}
    for _, w in ipairs(config.words) do
      existing[w] = true
    end
    local added = 0
    for _, w in ipairs(DEFAULT_WORDS) do
      if not existing[w] then
        table.insert(config.words, w)
        existing[w] = true
        added = added + 1
      end
    end
    if added > 0 then
      table.sort(config.words)
      local new_content = vim.fn.json_encode(config)
      vim.fn.writefile(vim.split(new_content, "\n"), config_path)
    end
  end

  vim.notify("[nvim-spell] Created cspell config: " .. config_path, vim.log.levels.INFO)
  return config_path
end

---Parse the JSON output from `cspell lint --reporter @cspell/cspell-json-reporter`.
---@param json_str string Raw JSON output from cspell lint
---@return table|nil Parsed issues list: { {text, lnum, col, end_col, suggestions} } or nil on parse error
M.parse_lint_output = function(json_str)
  if not json_str or json_str == "" then
    return {}
  end

  local ok, data = pcall(vim.fn.json_decode, json_str)
  if not ok then
    vim.notify("[nvim-spell] Failed to parse cspell output", vim.log.levels.ERROR)
    return nil
  end

  if not data or not data.issues then
    return {}
  end

  ---@type table[]
  local issues = {}
  for _, issue in ipairs(data.issues) do
    table.insert(issues, {
      text = issue.text,
      lnum = issue.row - 1, -- 0-indexed line number
      col = issue.col - 1, -- 0-indexed column
      end_col = issue.col - 1 + (issue.length or #issue.text),
      length = issue.length or #issue.text,
      suggestions = issue.suggestions or {},
      offset = issue.offset,
      is_flagged = issue.isFlagged or false,
    })
  end

  return issues
end

---Run `cspell lint` on a buffer asynchronously.
---Pipes buffer content to cspell via stdin and parses the JSON output.
---@param buf integer|nil Buffer handle (default: current)
---@param config_path string|nil Path to cspell config file
---@param callback fun(issues: table[]|nil, err: string|nil) Called with parsed issues or nil + error message
---@param cmd string|nil cspell binary
---@param locale string|nil Language locale(s) e.g. "en,zh-cn"
---@param dictionaries table|nil Dictionaries to enable, e.g. {'lua', 'bash'}
M.run_lint = function(buf, config_path, callback, cmd, locale, dictionaries)
  buf = buf or vim.api.nvim_get_current_buf()
  cmd = cmd or DEFAULT_CSPELL_CMD

  -- Build the stdin:// URI using the buffer's file path so cspell can infer file type
  local bufname = vim.api.nvim_buf_get_name(buf)
  local uri = "stdin://" .. (bufname ~= "" and bufname or vim.fn.getcwd() .. "/buffer")

  ---@type string[]
  local args = {
    cmd,
    "lint",
    uri,
    "--reporter",
    "@cspell/cspell-json-reporter",
    "--no-progress",
    "--no-summary",
    "--no-exit-code",
  }

  if config_path and vim.fn.filereadable(config_path) == 1 then
    table.insert(args, "-c")
    table.insert(args, config_path)
  end

  if locale and locale ~= "" then
    table.insert(args, "--locale")
    table.insert(args, locale)
  end

  dictionaries = dictionaries or {}
  for _, d in ipairs(dictionaries) do
    table.insert(args, "--dictionary")
    table.insert(args, d)
  end

  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local content = table.concat(lines, "\n")

  local stdout = {}
  local stderr = {}

  local job_id = vim.fn.jobstart(args, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stdout, line)
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stderr, line)
        end
      end
    end,
    on_exit = function(_, exit_code)
      local result = table.concat(stdout, "\n")
      local err_output = table.concat(stderr, "\n")

      -- exit_code can be non-zero even with --no-exit-code for actual errors
      -- cspell still outputs JSON on stderr for runtime errors
      if exit_code ~= 0 and result == "" and err_output ~= "" then
        -- Check if stderr contains JSON (cspell sometimes outputs to stderr)
        if vim.trim(err_output):sub(1, 1) == "{" then
          result = err_output
        else
          callback(nil, "cspell error (exit " .. exit_code .. "): " .. err_output)
          return
        end
      end

      local issues = M.parse_lint_output(result)
      if issues == nil then
        callback(nil, "Failed to parse cspell output")
        return
      end

      callback(issues, nil)
    end,
  })

  if job_id <= 0 then
    callback(nil, "Failed to start cspell process")
    return
  end

  -- Send buffer content to cspell via stdin
  vim.fn.chansend(job_id, content)
  vim.fn.chanclose(job_id, "stdin")
end

---Get spelling suggestions for a word synchronously.
---@param word string The misspelled word
---@param config_path string|nil Path to cspell config file
---@param cmd string|nil cspell binary
---@param locale string|nil Language locale(s) e.g. "en,zh-cn"
---@param dictionaries table|nil Dictionaries to enable, e.g. {'lua', 'bash'}
---@return string[] List of suggested corrections (empty if word is correct or no suggestions)
M.get_suggestions = function(word, config_path, cmd, locale, dictionaries)
  cmd = cmd or DEFAULT_CSPELL_CMD
  if not word or word == "" then
    return {}
  end

  ---@type string[]
  local args = { cmd, "suggestions", word, "--no-color", "--no-strict" }

  if config_path and vim.fn.filereadable(config_path) == 1 then
    table.insert(args, "-c")
    table.insert(args, config_path)
  end

  if locale and locale ~= "" then
    table.insert(args, "--locale")
    table.insert(args, locale)
  end

  dictionaries = dictionaries or {}
  for _, d in ipairs(dictionaries) do
    table.insert(args, "--dictionary")
    table.insert(args, d)
  end

  local output = vim.fn.system(args)
  local exit_code = vim.v.shell_error

  -- cspell suggestions exits 0 for "word found in dictionary" and 1 for "not found with suggestions"
  -- Both cases are valid -- we just need to parse the output
  if exit_code > 1 then
    -- Real error
    vim.notify("[nvim-spell] cspell suggestions failed: " .. vim.trim(output), vim.log.levels.WARN)
    return {}
  end

  -- Parse output: "word:\n - suggestion1\n - suggestion2\n"
  local suggestions = {}
  for line in output:gmatch("[^\n]+") do
    local suggestion = line:match("^ %- (.+)$")
    if suggestion then
      table.insert(suggestions, suggestion)
    end
  end

  return suggestions
end

---Add a word to a cspell config file's `words` array.
---@param word string The word to add
---@param config_path string Path to cspell.json (must exist)
---@return boolean success
M.add_word = function(word, config_path)
  if not word or word == "" then
    return false
  end

  if not config_path or vim.fn.filereadable(config_path) == 0 then
    vim.notify("[nvim-spell] Config file not found: " .. (config_path or "nil"), vim.log.levels.ERROR)
    return false
  end

  -- Read config
  local lines = vim.fn.readfile(config_path)
  if not lines or #lines == 0 then
    vim.notify("[nvim-spell] Config file is empty: " .. config_path, vim.log.levels.ERROR)
    return false
  end

  -- vim.fn.readfile returns lines with trailing newline already stripped.
  -- Use vim.fn.join to reconstruct the content.
  local content = vim.fn.join(lines, "\n")

  -- Strip single-line JSONC comments (// not inside a URL like https://)
  -- Match // that is NOT preceded by : (to preserve https://, etc.)
  content = content:gsub("(^|[^:])//[^\n]*", "%1")
  -- Strip block comments
  content = content:gsub("/%*.-%*/", "")

  local ok, config = pcall(vim.fn.json_decode, content)
  if not ok then
    vim.notify("[nvim-spell] Failed to parse cspell config as JSON: " .. config_path, vim.log.levels.ERROR)
    return false
  end

  -- Add word to 'words' array
  config.words = config.words or {}
  for _, existing in ipairs(config.words) do
    if existing == word then
      vim.notify('[nvim-spell] "' .. word .. '" is already in ' .. config_path, vim.log.levels.INFO)
      return true
    end
  end

  table.insert(config.words, word)
  table.sort(config.words)

  -- Write back
  local new_content = vim.fn.json_encode(config)
  -- json_encode doesn't add newlines between elements. Pretty-print by decoding/encoding again
  -- or just write as-is with the sorted words.
  vim.fn.writefile(vim.split(new_content, "\n"), config_path)
  vim.notify('[nvim-spell] Added "' .. word .. '" to ' .. config_path, vim.log.levels.INFO)
  return true
end

---Check if a word exists in the config's `words` or `ignoreWords` arrays.
---@param word string
---@param config_path string
---@return boolean
M.word_in_config = function(word, config_path)
  if not config_path or vim.fn.filereadable(config_path) == 0 then
    return false
  end

  local lines = vim.fn.readfile(config_path)
  local content = vim.fn.join(lines, "\n")
  content = content:gsub("(^|[^:])//[^\n]*", "%1")
  content = content:gsub("/%*.-%*/", "")

  local ok, config = pcall(vim.fn.json_decode, content)
  if not ok then
    return false
  end

  local words = config.words or {}
  for _, w in ipairs(words) do
    if w == word then
      return true
    end
  end

  local ignore_words = config.ignoreWords or {}
  for _, w in ipairs(ignore_words) do
    if w == word then
      return true
    end
  end

  return false
end

return M
