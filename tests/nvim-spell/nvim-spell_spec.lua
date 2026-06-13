local plugin = require('nvim-spell')

describe('nvim-spell setup', function()
  it('has default config', function()
    assert.is_not_nil(plugin.config)
    assert.equals('cspell', plugin.config.cspell_cmd)
    assert.equals(true, plugin.config.check_on_save)
    assert.equals(false, plugin.config.check_on_change)
    assert.equals(500, plugin.config.check_delay)
  end)

  it('setup merges user config', function()
    plugin.setup({
      check_on_save = false,
      check_delay = 1000,
    })
    assert.equals(false, plugin.config.check_on_save)
    assert.equals(1000, plugin.config.check_delay)
    -- Unchanged defaults
    assert.equals('cspell', plugin.config.cspell_cmd)

    -- Reset for other tests
    plugin.setup({})
  end)

  it('enable and disable work without error', function()
    -- Test that enable/disable don't crash
    plugin.enable()
    plugin.disable()
    -- Should not throw
    assert.is_true(true)
  end)

  it('setup accepts config_file path', function()
    local dir = vim.fn.tempname() .. '_cfg'
    vim.fn.mkdir(dir, 'p')
    local config_path = dir .. '/cspell.json'
    vim.fn.writefile({ '{"words":["myword"]}' }, config_path)

    plugin.setup({ config_file = config_path })
    assert.equals(config_path, vim.fn.expand(plugin.config.config_file))

    -- Cleanup
    plugin.setup({ config_file = nil })
    vim.fn.delete(config_path)
    vim.fn.delete(dir, 'd')
  end)

  it('setup accepts locale option', function()
    plugin.setup({ locale = 'en-US,zh-cn' })
    assert.equals('en-US,zh-cn', plugin.config.locale)

    -- Reset (nil doesn't work with tbl_deep_extend, so set directly)
    plugin.config.locale = nil
    assert.is_nil(plugin.config.locale)
  end)

  it('setup accepts locale with single language', function()
    plugin.setup({ locale = 'en-GB' })
    assert.equals('en-GB', plugin.config.locale)

    -- Reset
    plugin.config.locale = nil
    assert.is_nil(plugin.config.locale)
  end)
end)
