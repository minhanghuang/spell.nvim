-- Tests for bug fixes and improved functionality
local module = require("nvim-spell.module")

describe("Bug Fixes", function()
  before_each(function()
    -- Setup spell checking
    vim.opt.spell = true
    vim.opt.spelllang = 'en_us,cjk'
  end)

  describe("CJK character detection", function()
    it("detects Chinese characters correctly", function()
      local result = module.check_word("你好")
      assert.is_true(result.ok)
      assert.matches("CJK", result.message)
    end)

    it("detects Japanese Hiragana correctly", function()
      local result = module.check_word("こんにちは")
      assert.is_true(result.ok)
      assert.matches("CJK", result.message)
    end)

    it("detects Japanese Katakana correctly", function()
      local result = module.check_word("カタカナ")
      assert.is_true(result.ok)
      assert.matches("CJK", result.message)
    end)

    it("detects Korean Hangul correctly", function()
      local result = module.check_word("안녕하세요")
      assert.is_true(result.ok)
      assert.matches("CJK", result.message)
    end)

    it("does not flag English words as CJK", function()
      local result = module.check_word("hello")
      assert.is_true(result.ok)
      assert.matches("spelled correctly", result.message)
    end)
  end)

  describe("Word replacement", function()
    it("replaces word correctly when cursor is at the beginning", function()
      vim.cmd('new')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {"This is tset"})
      vim.api.nvim_win_set_cursor(0, {1, 8}) -- Cursor at 't' in 'tset'

      module.replace_current_word("test")
      local result = vim.api.nvim_get_current_line()

      assert.equals("This is test", result)
      vim.cmd('bdelete!')
    end)

    it("replaces word correctly when cursor is in the middle", function()
      vim.cmd('new')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {"This is tset"})
      vim.api.nvim_win_set_cursor(0, {1, 10}) -- Cursor at 'e' in 'tset'

      module.replace_current_word("test")
      local result = vim.api.nvim_get_current_line()

      assert.equals("This is test", result)
      vim.cmd('bdelete!')
    end)

    it("replaces word correctly when cursor is at the end", function()
      vim.cmd('new')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {"This is tset"})
      vim.api.nvim_win_set_cursor(0, {1, 11}) -- Cursor at 't' at end of 'tset'

      module.replace_current_word("test")
      local result = vim.api.nvim_get_current_line()

      assert.equals("This is test", result)
      vim.cmd('bdelete!')
    end)
  end)

  describe("Buffer spell check to quickfix", function()
    before_each(function()
      -- Clear quickfix list before each test
      vim.fn.setqflist({}, 'r')
    end)

    it("finds misspelled words and populates quickfix", function()
      vim.cmd('new')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "This is a tset of speling errors.",
        "Another lien with mistaks.",
      })

      module.check_buffer_to_qf()
      local qf = vim.fn.getqflist()

      -- Should find at least 3 misspellings: tset, speling, lien (or mistaks)
      assert.is_true(#qf >= 3, "Expected at least 3 misspellings, found " .. #qf)

      -- Verify that misspelled words are captured
      local found_words = {}
      for _, item in ipairs(qf) do
        table.insert(found_words, item.text)
      end

      -- Check for some expected misspellings
      local has_tset = vim.tbl_contains(found_words, "tset")
      local has_speling = vim.tbl_contains(found_words, "speling")

      assert.is_true(has_tset or has_speling, "Should find 'tset' or 'speling'")

      vim.cmd('bdelete!')
    end)

    it("reports no misspellings for correctly spelled text", function()
      vim.cmd('new')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "This is correctly spelled text.",
      })

      module.check_buffer_to_qf()
      local qf = vim.fn.getqflist()

      assert.equals(0, #qf)
      vim.cmd('bdelete!')
    end)

    it("correctly identifies column positions", function()
      vim.cmd('new')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Word tset here",  -- 'tset' starts at column 6 (1-indexed)
      })

      module.check_buffer_to_qf()
      local qf = vim.fn.getqflist()

      assert.is_true(#qf >= 1)
      -- The column should be around position 6 (where 'tset' starts)
      local tset_item = nil
      for _, item in ipairs(qf) do
        if item.text == "tset" then
          tset_item = item
          break
        end
      end

      assert.is_not_nil(tset_item)
      assert.equals(6, tset_item.col)

      vim.cmd('bdelete!')
    end)
  end)

  describe("Navigation functions", function()
    it("jumps to next misspelled word", function()
      vim.cmd('new')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Correct tset another mistke",
      })
      vim.api.nvim_win_set_cursor(0, {1, 0})

      -- Should jump to first misspelled word
      module.goto_next_misspelled()
      local pos = vim.api.nvim_win_get_cursor(0)

      -- Cursor should have moved from column 0
      assert.is_true(pos[2] > 0)

      vim.cmd('bdelete!')
    end)
  end)
end)
