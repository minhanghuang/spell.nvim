-- Tests for multi-window spell sync functionality
local plugin = require("nvim-spell")

describe("Multi-window spell sync", function()
  before_each(function()
    -- Clean setup
    vim.cmd("silent! %bwipeout!")
    plugin.setup({ enabled = true, spelllang = { "en_us" } })
  end)

  after_each(function()
    -- Clean up
    vim.cmd("silent! %bwipeout!")
  end)

  describe("Disable functionality", function()
    it("disables spell in all existing windows", function()
      -- Create multiple windows
      vim.cmd("new")
      vim.cmd("vnew")
      vim.cmd("new")

      -- Ensure spell is on initially
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        vim.api.nvim_win_set_option(win, "spell", true)
      end

      -- Disable spell
      plugin.disable()

      -- Verify all windows have spell disabled
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
          local spell_state = vim.api.nvim_win_get_option(win, "spell")
          assert.is_false(spell_state, "Window " .. win .. " should have spell disabled")
        end
      end
    end)

    it("applies disabled state to newly created windows", function()
      -- Disable spell first
      plugin.disable()

      -- Create a new window
      vim.cmd("new")

      -- Verify the new window has spell disabled
      local current_win = vim.api.nvim_get_current_win()
      local spell_state = vim.api.nvim_win_get_option(current_win, "spell")
      assert.is_false(spell_state, "New window should have spell disabled")
    end)
  end)

  describe("Enable functionality", function()
    it("enables spell in all existing windows", function()
      -- Create multiple windows
      vim.cmd("new")
      vim.cmd("vnew")

      -- Disable spell in all windows first
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        vim.api.nvim_win_set_option(win, "spell", false)
      end

      -- Enable spell
      plugin.enable()

      -- Verify all windows have spell enabled
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
          local spell_state = vim.api.nvim_win_get_option(win, "spell")
          assert.is_true(spell_state, "Window " .. win .. " should have spell enabled")
        end
      end
    end)

    it("applies enabled state to newly created windows", function()
      -- Enable spell first
      plugin.enable()

      -- Create a new window
      vim.cmd("new")

      -- Verify the new window has spell enabled
      local current_win = vim.api.nvim_get_current_win()
      local spell_state = vim.api.nvim_win_get_option(current_win, "spell")
      assert.is_true(spell_state, "New window should have spell enabled")
    end)
  end)

  describe("Toggle functionality", function()
    it("toggles spell state across all windows", function()
      -- Create multiple windows
      vim.cmd("new")
      vim.cmd("vnew")

      -- Enable spell first
      plugin.enable()

      -- Verify all enabled
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
          local spell_state = vim.api.nvim_win_get_option(win, "spell")
          assert.is_true(spell_state)
        end
      end

      -- Toggle to disable
      plugin.toggle_plugin()

      -- Verify all disabled
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
          local spell_state = vim.api.nvim_win_get_option(win, "spell")
          assert.is_false(spell_state)
        end
      end

      -- Toggle back to enable
      plugin.toggle_plugin()

      -- Verify all enabled again
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
          local spell_state = vim.api.nvim_win_get_option(win, "spell")
          assert.is_true(spell_state)
        end
      end
    end)
  end)

  describe("Exclude special windows", function()
    it("excludes file tree windows (NvimTree)", function()
      -- Create a regular window
      vim.cmd("new")
      local regular_win = vim.api.nvim_get_current_win()

      -- Create a mock NvimTree window
      vim.cmd("new")
      local tree_win = vim.api.nvim_get_current_win()
      local tree_buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_option(tree_buf, "filetype", "NvimTree")

      -- Enable spell
      plugin.enable()

      -- Regular window should have spell enabled
      local regular_spell = vim.api.nvim_win_get_option(regular_win, "spell")
      assert.is_true(regular_spell, "Regular window should have spell enabled")

      -- Tree window should NOT have spell enabled
      local tree_spell = vim.api.nvim_win_get_option(tree_win, "spell")
      assert.is_false(tree_spell, "NvimTree window should not have spell enabled")
    end)

    it("excludes neo-tree windows", function()
      vim.cmd("new")
      local regular_win = vim.api.nvim_get_current_win()

      vim.cmd("new")
      local tree_win = vim.api.nvim_get_current_win()
      local tree_buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_option(tree_buf, "filetype", "neo-tree")

      plugin.enable()

      local regular_spell = vim.api.nvim_win_get_option(regular_win, "spell")
      assert.is_true(regular_spell)

      local tree_spell = vim.api.nvim_win_get_option(tree_win, "spell")
      assert.is_false(tree_spell)
    end)

    it("excludes terminal windows", function()
      vim.cmd("new")
      local regular_win = vim.api.nvim_get_current_win()

      -- Create a buffer with terminal buftype
      vim.cmd("new")
      local term_win = vim.api.nvim_get_current_win()
      local term_buf = vim.api.nvim_get_current_buf()
      -- Use nofile as a proxy since we can't easily create real terminal in tests
      vim.api.nvim_buf_set_option(term_buf, "buftype", "nofile")

      plugin.enable()

      local regular_spell = vim.api.nvim_win_get_option(regular_win, "spell")
      assert.is_true(regular_spell)

      local term_spell = vim.api.nvim_win_get_option(term_win, "spell")
      assert.is_false(term_spell)
    end)

    it("respects user-configured exclude_filetypes", function()
      -- Setup with custom exclusion
      plugin.setup({
        enabled = true,
        spelllang = { "en_us" },
        exclude_filetypes = { "myspecial" },
      })

      vim.cmd("new")
      local regular_win = vim.api.nvim_get_current_win()

      vim.cmd("new")
      local special_win = vim.api.nvim_get_current_win()
      local special_buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_option(special_buf, "filetype", "myspecial")

      plugin.enable()

      local regular_spell = vim.api.nvim_win_get_option(regular_win, "spell")
      assert.is_true(regular_spell, "Regular window should have spell enabled")

      local special_spell = vim.api.nvim_win_get_option(special_win, "spell")
      assert.is_false(special_spell, "Custom excluded filetype window should not have spell enabled")
    end)
  end)

  describe("Cross-buffer synchronization", function()
    it("synchronizes spell state across different buffers", function()
      -- Create multiple buffers with windows
      vim.cmd("new")
      local buf1 = vim.api.nvim_get_current_buf()
      vim.cmd("new")
      local buf2 = vim.api.nvim_get_current_buf()
      vim.cmd("new")
      local buf3 = vim.api.nvim_get_current_buf()

      -- Disable spell from one buffer
      plugin.disable()

      -- Check all buffers' windows have spell disabled
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
          local spell_state = vim.api.nvim_win_get_option(win, "spell")
          assert.is_false(spell_state, "All windows should have spell disabled")
        end
      end
    end)
  end)
end)
