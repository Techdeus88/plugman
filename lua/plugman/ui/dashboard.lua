local Logger = require('plugman.utils.logger')

local M = {}

---Show dashboard
---@param manager PlugmanManager
function M.show(manager)
  local plugins = manager:get_plugins()
  local config = manager.config

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Generate content
  local lines = M.generate_content(plugins, config)

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'plugman')

  -- Create window
  local width = math.floor(vim.o.columns * config.ui.width)
  local height = math.floor(vim.o.lines * config.ui.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = config.ui.border,
    title = ' Plugman ',
    title_pos = 'center',
  })

  -- Set window options
  vim.api.nvim_win_set_option(win, 'wrap', false)
  vim.api.nvim_win_set_option(win, 'cursorline', true)

  -- Setup highlighting
  M.setup_highlighting()

  -- Setup keymaps
  M.setup_keymaps(buf, win, manager)

  Logger.info("Dashboard opened")
end

---Generate dashboard content
---@param plugins table<string, PlugmanPlugin>
---@param config table Configuration
---@return table Lines
function M.generate_content(plugins, config)
  local lines = {}
  local icons = config.ui.icons

  -- Header
  table.insert(lines, "                     🔌                   ")
  table.insert(lines, "  ╭──────────────────────────────────────╮")
  table.insert(lines, "  │               Plugman                │")
  table.insert(lines, "  │      Plugin Manager for Neovim       │")
  table.insert(lines, "  ╰──────────────────────────────────────╯")
  table.insert(lines, "                     🔌                   ")


  -- Stats
  local total = vim.tbl_count(plugins)
  local installed = 0
  local added = 0
  local loaded = 0
  local lazy = 0

  for _, plugin in pairs(plugins) do
    if plugin.installed then installed = installed + 1 end
    if plugin.added then added = added + 1 end
    if plugin.loaded then loaded = loaded + 1 end
    if plugin.lazy then lazy = lazy + 1 end
  end

  table.insert(lines, string.format("  📊 Stats: %d total, %d installed, %d added, %d loaded, %d lazy",
    total, installed, added, loaded, lazy))
  table.insert(lines, "")
  table.insert(lines, "  ─────────────────────────────────────")
  table.insert(lines, "")

  -- Plugin list
  local sorted_plugins = {}
  for name, plugin in pairs(plugins) do
    table.insert(sorted_plugins, { name = name, plugin = plugin })
  end

  table.sort(sorted_plugins, function(a, b)
    -- Sort by priority first, then by name
    if a.plugin.priority ~= b.plugin.priority then
      return a.plugin.priority > b.plugin.priority
    end
    return string.lower(a.name) < string.lower(b.name)
  end)

  for _, item in ipairs(sorted_plugins) do
    local name = item.name
    local plugin = item.plugin

    local status_icon = plugin.installed and icons.installed or icons.not_installed
    local added_icon  = plugin.added and icons.added or icons.not_added
    local load_icon = plugin.loaded and icons.loaded or icons.not_loaded
    local lazy_icon = plugin.lazy and icons.lazy or plugin.lazy == false and icons.not_lazy
    local priority_icon = plugin.priority > 0 and icons.priority or "  "

    local line = string.format("  %s %s %s %s %s",
      status_icon, added_icon, load_icon, lazy_icon, priority_icon, name)

    if plugin.priority > 0 then
      line = line .. string.format(" (priority: %d)", plugin.priority)
    end

    table.insert(lines, line)
  end

  -- Footer
  table.insert(lines, "")
  table.insert(lines, "  ─────────────────────────────────────")
  table.insert(lines, "")
  table.insert(lines, "  Keymaps:")
  table.insert(lines, "    i - Install plugin")
  table.insert(lines, "    u - Update plugin")
  table.insert(lines, "    d - Remove plugin")
  table.insert(lines, "    r - Reload plugin")
  table.insert(lines, "    U - Update all")
  table.insert(lines, "    q - Quit")
  table.insert(lines, "")

  return lines
end

---Setup highlighting
function M.setup_highlighting()
  vim.cmd([[
        highlight PlugmanHeader guifg=#61AFEF gui=bold
        highlight PlugmanInstalled guifg=#98C379
        highlight PlugmanNotInstalled guifg=#E06C75
        highlight PlugmanLoaded guifg=#98C379
        highlight PlugmanNotLoaded guifg=#ABB2BF
        highlight PlugmanLazy guifg=#C678DD
        highlight PlugmanPriority guifg=#E5C07B
    ]])
end

---Setup keymaps
---@param buf number Buffer handle
---@param win number Window handle
---@param manager PlugmanManager
function M.setup_keymaps(buf, win, manager)
  local opts = { buffer = buf, nowait = true, silent = true }

  -- Quit
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, opts)

  -- Get plugin under cursor
  local function get_current_plugin()
    local line = vim.api.nvim_get_current_line()
    local name = line:match("  [●○] [✓✗] [💤 ] [⚡ ] ([%w%-%._]+)")
    return name and manager.plugins[name]
  end

  -- Install plugin
  vim.keymap.set('n', 'i', function()
    local plugin = get_current_plugin()
    if plugin and not plugin.installed then
      manager:install(plugin)
      vim.cmd('redraw')
    end
  end, opts)

  -- Update plugin
  vim.keymap.set('n', 'u', function()
    local plugin = get_current_plugin()
    if plugin and plugin.installed then
      manager:update({ plugin.name })
      vim.cmd('redraw')
    end
  end, opts)

  -- Remove plugin
  vim.keymap.set('n', 'd', function()
    local plugin = get_current_plugin()
    if plugin then
      manager:remove(plugin.name)
      vim.cmd('redraw')
    end
  end, opts)

  -- Reload plugin
  vim.keymap.set('n', 'r', function()
    local plugin = get_current_plugin()
    if plugin and plugin.installed then
      manager:load(plugin)
      vim.cmd('redraw')
    end
  end, opts)

  -- Update all
  vim.keymap.set('n', 'U', function()
    manager:update()
    vim.cmd('redraw')
  end, opts)
end

return M

-- local M = {}

-- function M.open(state)
--   -- Check if we're in cmdwin
--   if vim.fn.getcmdwintype() ~= '' then
--     vim.notify('Cannot open dashboard in command-line window', vim.log.levels.ERROR)
--     return
--   end

--   local buf = vim.api.nvim_create_buf(false, true)
--   local win = vim.api.nvim_open_win(buf, true, {
--     relative = 'editor',
--     width = math.floor(vim.o.columns * 0.8),
--     height = math.floor(vim.o.lines * 0.8),
--     col = math.floor(vim.o.columns * 0.1),
--     row = math.floor(vim.o.lines * 0.1),
--     style = 'minimal',
--     border = 'rounded',
--     title = ' Plugman Dashboard ',
--     title_pos = 'center'
--   })

--   local lines = M.generate_content(state)
--   vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
--   vim.api.nvim_buf_set_option(buf, 'modifiable', false)
--   vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

--   -- Setup keymaps
--   local opts = { buffer = buf, silent = true }
--   vim.keymap.set('n', 'q', '<cmd>close<cr>', opts)
--   vim.keymap.set('n', '<esc>', '<cmd>close<cr>', opts)
--   vim.keymap.set('n', 'r', function()
--     M.refresh(buf, state)
--   end, opts)
-- end

-- function M.generate_content(state)
--   local lines = {}

--   -- Header
--   table.insert(lines, '╭─ PLUGMAN DASHBOARD ─╮')
--   table.insert(lines, '│                      │')

--   -- Stats
--   local total = vim.tbl_count(state.plugins)
--   local loaded = 0
--   local lazy = 0

--   for _, plugin in pairs(state.plugins) do
--     if plugin.loaded then loaded = loaded + 1 end
--     if plugin.lazy then lazy = lazy + 1 end
--   end

--   table.insert(lines, string.format('│ Total: %d            │', total))
--   table.insert(lines, string.format('│ Loaded: %d           │', loaded))
--   table.insert(lines, string.format('│ Lazy: %d             │', lazy))
--   table.insert(lines, '│                      │')
--   table.insert(lines, '╰──────────────────────╯')
--   table.insert(lines, '')

--   -- Priority plugins
--   if #state.loading_order.priority > 0 then
--     table.insert(lines, '🚀 Priority Plugins:')
--     for _, plugin in ipairs(state.loading_order.priority) do
--       local status = plugin.loaded and '✓' or '○'
--       table.insert(lines, string.format('  %s %s (priority: %d)', status, plugin.name, plugin.priority))
--     end
--     table.insert(lines, '')
--   end

--   -- Normal plugins
--   if #state.loading_order.normal > 0 then
--     table.insert(lines, '⚡ Normal Plugins:')
--     for _, plugin in ipairs(state.loading_order.normal) do
--       local status = plugin.loaded and '✓' or '○'
--       table.insert(lines, string.format('  %s %s', status, plugin.name))
--     end
--     table.insert(lines, '')
--   end

--   -- Lazy plugins
--   if #state.loading_order.lazy > 0 then
--     table.insert(lines, '💤 Lazy Plugins:')
--     for _, plugin in ipairs(state.loading_order.lazy) do
--       local status = plugin.loaded and '✓' or '💤'
--       local triggers = {}
--       if plugin.cmd ~= nil then table.insert(triggers, { type = 'cmd', value = table.concat(plugin.cmd, ",")} ) end
--       if plugin.event ~= nil then table.insert(triggers, { type = 'event', value = table.concat(plugin.event, ",") }) end
--       if plugin.ft ~= nil then table.insert(triggers, { type = 'ft', value = table.concat(plugin.ft, ",")} ) end
--       if plugin.keys ~= nil then table.insert(triggers, { type = 'keys', value = table.concat(plugin.keys, ",")}) end

--       local trigger_str = ''
--       if #triggers > 0 then
--         local trigger_parts = {}
--         for _, trigger in ipairs(triggers) do
--           table.insert(trigger_parts, string.format('%s: %s', trigger.type, trigger.value))
--         end
--         trigger_str = ' [' .. table.concat(trigger_parts, ', ') .. ']'
--       end
--       table.insert(lines, string.format('  %s %s%s', status, plugin.name, trigger_str))
--     end
--   end

--   table.insert(lines, '')
--   table.insert(lines, 'Press "r" to refresh, "q" to quit')

--   return lines
-- end

-- function M.refresh(buf, state)
--   -- Check if buffer is still valid
--   if not vim.api.nvim_buf_is_valid(buf) then
--     vim.notify('Dashboard buffer is no longer valid', vim.log.levels.WARN)
--     return
--   end

--   local lines = M.generate_content(state)
--   vim.api.nvim_buf_set_option(buf, 'modifiable', true)
--   vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
--   vim.api.nvim_buf_set_option(buf, 'modifiable', false)
-- end

-- return M
