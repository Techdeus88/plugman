local M = {}

function M.open(state)
  -- Check if we're in cmdwin
  if vim.fn.getcmdwintype() ~= '' then
    vim.notify('Cannot open dashboard in command-line window', vim.log.levels.ERROR)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
    col = math.floor(vim.o.columns * 0.1),
    row = math.floor(vim.o.lines * 0.1),
    style = 'minimal',
    border = 'rounded',
    title = ' Plugman Dashboard ',
    title_pos = 'center'
  })
  
  local lines = M.generate_content(state)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  
  -- Setup keymaps
  local opts = { buffer = buf, silent = true }
  vim.keymap.set('n', 'q', '<cmd>close<cr>', opts)
  vim.keymap.set('n', '<esc>', '<cmd>close<cr>', opts)
  vim.keymap.set('n', 'r', function()
    M.refresh(buf, state)
  end, opts)
end

function M.generate_content(state)
  local lines = {}
  
  -- Header
  table.insert(lines, '╭─ PLUGMAN DASHBOARD ─╮')
  table.insert(lines, '│                      │')
  
  -- Stats
  local total = vim.tbl_count(state.plugins)
  local loaded = 0
  local lazy = 0
  
  for _, plugin in pairs(state.plugins) do
    if plugin.loaded then loaded = loaded + 1 end
    if plugin.lazy then lazy = lazy + 1 end
  end
  
  table.insert(lines, string.format('│ Total: %d            │', total))
  table.insert(lines, string.format('│ Loaded: %d           │', loaded))
  table.insert(lines, string.format('│ Lazy: %d             │', lazy))
  table.insert(lines, '│                      │')
  table.insert(lines, '╰──────────────────────╯')
  table.insert(lines, '')
  
  -- Priority plugins
  if #state.loading_order.priority > 0 then
    table.insert(lines, '🚀 Priority Plugins:')
    for _, plugin in ipairs(state.loading_order.priority) do
      local status = plugin.loaded and '✓' or '○'
      table.insert(lines, string.format('  %s %s (priority: %d)', status, plugin.name, plugin.priority))
    end
    table.insert(lines, '')
  end
  
  -- Normal plugins
  if #state.loading_order.normal > 0 then
    table.insert(lines, '⚡ Normal Plugins:')
    for _, plugin in ipairs(state.loading_order.normal) do
      local status = plugin.loaded and '✓' or '○'
      table.insert(lines, string.format('  %s %s', status, plugin.name))
    end
    table.insert(lines, '')
  end
  
  -- Lazy plugins
  if #state.loading_order.lazy > 0 then
    table.insert(lines, '💤 Lazy Plugins:')
    for _, plugin in ipairs(state.loading_order.lazy) do
      local status = plugin.loaded and '✓' or '💤'
      local triggers = {}
      if plugin.cmd then table.insert(triggers, { type = 'cmd', value = table.concat(plugin.cmd, ",")} ) end
      if plugin.event then table.insert(triggers, { type = 'event', value = table.concat(plugin.event, ",") }) end
      if plugin.ft then table.insert(triggers, { type = 'ft', value = table.concat(plugin.ft, ",")} ) end
      if plugin.keys then table.insert(triggers, { type = 'keys', value = table.concat(plugin.keys, ",")}) end

      local trigger_str = #triggers > 0 and (' [' .. triggers.type .. ': ' .. triggers.value .. ']') or ''
      table.insert(lines, string.format('  %s %s%s', status, plugin.name, trigger_str))
    end
  end
  
  table.insert(lines, '')
  table.insert(lines, 'Press "r" to refresh, "q" to quit')
  
  return lines
end

function M.refresh(buf, state)
  -- Check if buffer is still valid
  if not vim.api.nvim_buf_is_valid(buf) then
    vim.notify('Dashboard buffer is no longer valid', vim.log.levels.WARN)
    return
  end

  local lines = M.generate_content(state)
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

return M