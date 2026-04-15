# Multi-Window Spell Synchronization Demo

## 功能说明

当你在 Neovim 中打开多个窗口/buffer 时，拼写检查状态会自动在所有窗口间同步：

### 使用场景示例

```vim
" 1. 打开多个窗口
:new file1.txt
:vnew file2.txt
:new file3.txt

" 2. 在任意一个窗口中禁用拼写检查
:SpellDisable

" ✅ 结果：所有窗口（file1.txt, file2.txt, file3.txt）的拼写检查都被禁用

" 3. 在任意一个窗口中启用拼写检查
:SpellEnable

" ✅ 结果：所有窗口的拼写检查都被重新启用

" 4. 打开新窗口
:new file4.txt

" ✅ 结果：新窗口自动继承当前的拼写检查状态（启用）
```

### 在 Lua 中使用

```lua
-- 设置插件
require('nvim-spell').setup({
  enabled = true,
  spelllang = { 'en_us,cjk' },
})

-- 在代码中控制拼写检查
vim.keymap.set('n', '<leader>sd', function()
  require('nvim-spell').disable()  -- 禁用所有窗口的拼写检查
end, { desc = 'Disable spell (all windows)' })

vim.keymap.set('n', '<leader>se', function()
  require('nvim-spell').enable()   -- 启用所有窗口的拼写检查
end, { desc = 'Enable spell (all windows)' })

vim.keymap.set('n', '<leader>st', function()
  require('nvim-spell').toggle_plugin()  -- 切换所有窗口的拼写检查
end, { desc = 'Toggle spell (all windows)' })
```

## 技术实现

### 核心机制

1. **全局状态追踪**：使用 `plugin_state.spell_enabled` 追踪插件级别的拼写检查状态

2. **遍历所有窗口**：`apply_spell_to_all_windows()` 函数遍历所有现有窗口并应用相同设置

3. **自动命令同步**：通过 autocommand 监听 `WinNew` 和 `BufWinEnter` 事件，确保新窗口继承当前状态

### 关键代码片段

```lua
-- 应用设置到所有窗口
local function apply_spell_to_all_windows(enabled)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_option(win, 'spell', enabled)
    end
  end
end

-- 自动同步新窗口
vim.api.nvim_create_autocmd({ 'WinNew', 'BufWinEnter' }, {
  group = 'NvimSpellSync',
  callback = function()
    if plugin_state.spell_enabled ~= nil then
      vim.wo.spell = plugin_state.spell_enabled
    end
  end,
})
```

## 优势

- ✅ **一次操作，全局生效**：不需要在每个窗口中重复操作
- ✅ **自动继承**：新窗口自动应用当前状态
- ✅ **无需手动追踪**：插件自动管理所有窗口的状态
- ✅ **开箱即用**：安装插件后自动启用，无需额外配置

## 测试验证

所有功能都经过完整测试（6 个测试用例）：
- ✅ 禁用时同步所有现有窗口
- ✅ 禁用状态应用到新窗口
- ✅ 启用时同步所有现有窗口
- ✅ 启用状态应用到新窗口
- ✅ 切换功能正常工作
- ✅ 跨 buffer 同步正常

运行测试：
```bash
make test
```
