-- Tests for the cspell CLI integration module
local cspell = require("nvim-spell.cspell")

local has_cspell = cspell.is_cspell_available()

-- Helper: skip test body if cspell is not available
local function require_cspell(fn)
  return function()
    if not has_cspell then
      return
    end
    fn()
  end
end

describe("cspell integration", function()
  describe("is_cspell_available", function()
    it("returns a boolean", function()
      local available = cspell.is_cspell_available()
      assert.is_boolean(available)
    end)

    it("returns false for nonexistent binary", function()
      local available = cspell.is_cspell_available("nonexistent-binary-xyz")
      assert.is_false(available)
    end)
  end)

  -- These tests don't need cspell binary
  describe("find_config", function()
    it("finds cspell.json in current directory", function()
      local dir = vim.fn.tempname() .. "_dir"
      vim.fn.mkdir(dir, "p")
      local config_path = dir .. "/cspell.json"
      vim.fn.writefile({ '{"words":[]}' }, config_path)

      local filepath = dir .. "/test.txt"
      vim.cmd("new " .. vim.fn.fnameescape(filepath))
      local buf = vim.api.nvim_get_current_buf()

      local found = cspell.find_config(buf)
      assert.equals(vim.fn.resolve(config_path), vim.fn.resolve(found))

      vim.cmd("bdelete!")
      vim.fn.delete(config_path)
      vim.fn.delete(dir, "d")
    end)

    it("finds config in parent directory", function()
      local dir = vim.fn.tempname() .. "_dir"
      local subdir = dir .. "/sub"
      vim.fn.mkdir(subdir, "p")
      local config_path = dir .. "/cspell.json"
      vim.fn.writefile({ '{"words":[]}' }, config_path)

      local filepath = subdir .. "/test.txt"
      vim.cmd("new " .. vim.fn.fnameescape(filepath))
      local buf = vim.api.nvim_get_current_buf()

      local found = cspell.find_config(buf)
      assert.equals(vim.fn.resolve(config_path), vim.fn.resolve(found))

      vim.cmd("bdelete!")
      vim.fn.delete(config_path)
      vim.fn.delete(subdir, "d")
      vim.fn.delete(dir, "d")
    end)

    it("returns nil when no config found", function()
      local dir = vim.fn.tempname() .. "_empty"
      vim.fn.mkdir(dir, "p")

      local filepath = dir .. "/test.txt"
      vim.cmd("new " .. vim.fn.fnameescape(filepath))
      local buf = vim.api.nvim_get_current_buf()

      local found = cspell.find_config(buf)
      assert.is_nil(found)

      vim.cmd("bdelete!")
      vim.fn.delete(dir, "d")
    end)
  end)

  describe("parse_lint_output", function()
    it("parses valid JSON lint output", function()
      local json = [[
{
  "issues": [
    {
      "text": "tset",
      "offset": 10,
      "row": 1,
      "col": 11,
      "length": 4,
      "suggestions": ["test", "set"]
    },
    {
      "text": "speling",
      "offset": 23,
      "row": 2,
      "col": 9,
      "length": 7,
      "suggestions": ["spelling"]
    }
  ]
}
]]
      local issues = cspell.parse_lint_output(json)
      assert.is_not_nil(issues)
      assert.equals(2, #issues)

      assert.equals("tset", issues[1].text)
      assert.equals(0, issues[1].lnum)
      assert.equals(10, issues[1].col)
      assert.equals(14, issues[1].end_col)
      assert.are.same({ "test", "set" }, issues[1].suggestions)

      assert.equals("speling", issues[2].text)
      assert.equals(1, issues[2].lnum)
      assert.equals(8, issues[2].col)
      assert.equals(15, issues[2].end_col)
      assert.are.same({ "spelling" }, issues[2].suggestions)
    end)

    it("returns empty list for empty JSON output", function()
      assert.are.same({}, cspell.parse_lint_output(""))
    end)

    it("returns empty list for output with no issues", function()
      assert.are.same({}, cspell.parse_lint_output('{"issues":[],"result":{"issues":0}}'))
    end)

    it("returns nil for invalid JSON", function()
      assert.is_nil(cspell.parse_lint_output("not json"))
    end)
  end)

  describe("add_word", function()
    it("adds a word to cspell.json words array", function()
      local dir = vim.fn.tempname() .. "_cfg"
      vim.fn.mkdir(dir, "p")
      local config_path = dir .. "/cspell.json"
      vim.fn.writefile({ '{"words":["existing"]}' }, config_path)

      local result = cspell.add_word("newtest", config_path)
      assert.is_true(result)

      local content = vim.fn.join(vim.fn.readfile(config_path), "\n")
      local config = vim.fn.json_decode(content)
      assert.is_not_nil(config.words)
      assert.is_true(vim.tbl_contains(config.words, "existing"))
      assert.is_true(vim.tbl_contains(config.words, "newtest"))

      vim.fn.delete(config_path)
      vim.fn.delete(dir, "d")
    end)

    it("does not duplicate existing words", function()
      local dir = vim.fn.tempname() .. "_cfg"
      vim.fn.mkdir(dir, "p")
      local config_path = dir .. "/cspell.json"
      vim.fn.writefile({ '{"words":["existing"]}' }, config_path)

      local result = cspell.add_word("existing", config_path)
      assert.is_true(result)

      local content = vim.fn.join(vim.fn.readfile(config_path), "\n")
      local config = vim.fn.json_decode(content)
      local count = 0
      for _, w in ipairs(config.words) do
        if w == "existing" then
          count = count + 1
        end
      end
      assert.equals(1, count)

      vim.fn.delete(config_path)
      vim.fn.delete(dir, "d")
    end)

    it("returns false for nonexistent config", function()
      assert.is_false(cspell.add_word("test", "/nonexistent/path/cspell.json"))
    end)
  end)

  -- These tests require cspell CLI
  describe("get_suggestions (needs cspell)", function()
    it(
      "returns suggestions for a misspelled word",
      require_cspell(function()
        local suggestions = cspell.get_suggestions("tset")
        assert.is_true(#suggestions > 0, "should have at least one suggestion")
        local has_test = false
        for _, s in ipairs(suggestions) do
          if s == "test" then
            has_test = true
            break
          end
        end
        assert.is_true(has_test, '"test" should be a suggestion for "tset"')
      end)
    )

    it("returns empty list for empty word", function()
      assert.are.same({}, cspell.get_suggestions(""))
    end)
  end)

  describe("get_suggestions with locale (needs cspell)", function()
    it(
      "respects en-GB locale (colour is correct)",
      require_cspell(function()
        local s = cspell.get_suggestions("colour", nil, "cspell", "en-GB")
        assert.is_true(#s > 0)
        assert.equals("colour", s[1])
      end)
    )

    it(
      "respects en-US locale (colour is misspelled)",
      require_cspell(function()
        local s = cspell.get_suggestions("colour", nil, "cspell", "en-US")
        assert.is_true(#s > 0)
        assert.equals("color", s[1])
      end)
    )
  end)

  describe("run_lint (needs cspell)", function()
    it(
      "finds misspelled words in buffer content",
      require_cspell(function()
        vim.cmd("new")
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "This is a tset word" })

        local done = false
        local result_issues, result_err = nil, nil

        cspell.run_lint(0, nil, function(issues, err)
          result_issues = issues
          result_err = err
          done = true
        end)

        vim.wait(5000, function()
          return done
        end)

        assert.is_true(done)
        assert.is_nil(result_err)
        assert.is_not_nil(result_issues)
        assert.is_true(#result_issues >= 1)
        local found_tset = false
        for _, issue in ipairs(result_issues) do
          if issue.text == "tset" then
            found_tset = true
            break
          end
        end
        assert.is_true(found_tset)

        vim.cmd("bdelete!")
      end)
    )

    it(
      "returns empty for correctly spelled content",
      require_cspell(function()
        vim.cmd("new")
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "This is correctly spelled" })

        local done = false
        local result_issues = nil

        cspell.run_lint(0, nil, function(issues, _)
          result_issues = issues
          done = true
        end)

        vim.wait(5000, function()
          return done
        end)

        assert.is_true(done)
        assert.are.same({}, result_issues)

        vim.cmd("bdelete!")
      end)
    )
  end)
end)
