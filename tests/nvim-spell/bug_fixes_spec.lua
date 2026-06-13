-- Tests for bug fixes and improved functionality (updated for cspell backend)
local module = require("nvim-spell.module")
local cspell = require("nvim-spell.cspell")

local has_cspell = cspell.is_cspell_available()

local function require_cspell(fn)
  return function()
    if not has_cspell then
      return
    end
    fn()
  end
end

describe("Bug Fixes", function()
  before_each(function()
    -- Clear diagnostics
    vim.diagnostic.set(module.diagnostic_namespace, 0, {})
  end)

  describe("Word replacement", function()
    it("replaces word correctly when cursor is at the beginning", function()
      vim.cmd("new")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "This is tset" })
      vim.api.nvim_win_set_cursor(0, { 1, 8 }) -- Cursor at 't' in 'tset'

      module.replace_current_word("test")
      local result = vim.api.nvim_get_current_line()

      assert.equals("This is test", result)
      vim.cmd("bdelete!")
    end)

    it("replaces word correctly when cursor is in the middle", function()
      vim.cmd("new")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "This is tset" })
      vim.api.nvim_win_set_cursor(0, { 1, 10 }) -- Cursor at 'e' in 'tset'

      module.replace_current_word("test")
      local result = vim.api.nvim_get_current_line()

      assert.equals("This is test", result)
      vim.cmd("bdelete!")
    end)

    it("replaces word correctly when cursor is at the end", function()
      vim.cmd("new")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "This is tset" })
      vim.api.nvim_win_set_cursor(0, { 1, 11 }) -- Cursor at 't' at end of 'tset'

      module.replace_current_word("test")
      local result = vim.api.nvim_get_current_line()

      assert.equals("This is test", result)
      vim.cmd("bdelete!")
    end)
  end)

  describe("Buffer spell check", function()
    before_each(function()
      vim.fn.setqflist({}, "r")
    end)

    it(
      "finds misspelled words via async lint",
      require_cspell(function()
        vim.cmd("new")
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "This is a tset of speling errors.",
          "Another lien with mistaks.",
        })

        local result1 = module.check_word("tset")
        local result2 = module.check_word("speling")

        assert.is_false(result1.ok, "tset should be misspelled")
        assert.is_false(result2.ok, "speling should be misspelled")
        assert.is_true(#result1.suggestions > 0, "tset should have suggestions")

        vim.cmd("bdelete!")
      end)
    )

    it(
      "reports correctly for correctly spelled text",
      require_cspell(function()
        local result = module.check_word("hello")
        assert.is_true(result.ok)
      end)
    )

    it("returns no word for empty input", function()
      local result = module.check_word("")
      assert.is_true(result.ok)
      assert.equals("no word", result.message)
    end)
  end)

  describe("Navigation functions", function()
    it("has diagnostic namespace configured", function()
      assert.is_not_nil(module.diagnostic_namespace)
    end)
  end)

  describe("cspell suggestions", function()
    it(
      "returns suggestions from cspell",
      require_cspell(function()
        local suggestions = cspell.get_suggestions("recieve")
        assert.is_true(#suggestions > 0, "should have suggestions for recieve")
      end)
    )
  end)
end)
