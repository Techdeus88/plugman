local Logger = require('plugman.utils.logger')

local M = {}

-- Cache for plugin sorting and stats
local cache = {
  sorted_plugins = nil,
  stats = nil,
  last_update = 0
}

-- Constants
local CACHE_TTL = 30000 -- 30 seconds
local SECTIONS = {
  HEADER = 1,
  STATS = 2,
  PLUGINS = 3,
  FOOTER = 4
}

---Show dashboard
---@param manager PlugmanManager
function M.show(manager)
  local plugins = manager:get_plugins()
  local config = manager.config
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  -- Generate content asynchronously
  vim.schedule(function()
    local lines = M.generate_content(plugins, config)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'plugman')
  end)

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
  vim.api.nvim_win_set_option(win, 'number', false)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(win, 'signcolumn', 'no')

  -- Setup highlighting
  M.setup_highlighting()
  -- Setup keymaps
  M.setup_keymaps(buf, win, manager)

  Logger.info("Dashboard opened")
end

---Calculate plugin stats
---@param plugins table<string, PlugmanPlugin>
---@return table Stats
local function calculate_stats(plugins)
  local stats = {
    total = 0,
    installed = 0,
    added = 0,
    loaded = 0,
    lazy = 0,
    priority = 0,
    normal = 0  -- Add normal plugins count
  }

  for _, plugin in pairs(plugins) do
    stats.total = stats.total + 1
    if plugin.installed then stats.installed = stats.installed + 1 end
    if plugin.added then stats.added = stats.added + 1 end
    if plugin.loaded then stats.loaded = stats.loaded + 1 end
    if plugin.lazy then stats.lazy = stats.lazy + 1 end
    if plugin.priority > 0 then 
      stats.priority = stats.priority + 1 
    elseif not plugin.lazy then
      stats.normal = stats.normal + 1  -- Count normal plugins
    end
  end

  return stats
end

---Get cached or calculate stats
---@param plugins table<string, PlugmanPlugin>
---@return table Stats
local function get_stats(plugins)
  local now = vim.loop.now()
  if cache.stats and (now - cache.last_update) < CACHE_TTL then
    return cache.stats
  end

  cache.stats = calculate_stats(plugins)
  cache.last_update = now
  return cache.stats
end

---Sort plugins
---@param plugins table<string, PlugmanPlugin>
---@return table Sorted plugins
local function sort_plugins(plugins)
  local now = vim.loop.now()
  if cache.sorted_plugins and (now - cache.last_update) < CACHE_TTL then
    return cache.sorted_plugins
  end

  -- Separate plugins into categories
  local priority_plugins = {}
  local normal_plugins = {}
  local lazy_plugins = {}

  for name, plugin in pairs(plugins) do
    local entry = { name = name, plugin = plugin }
    if plugin.priority > 0 then
      table.insert(priority_plugins, entry)
    elseif not plugin.lazy then
      table.insert(normal_plugins, entry)
    else
      table.insert(lazy_plugins, entry)
    end
  end

  -- Sort each category
  -- Priority plugins: sort by priority (highest first), then load order, then alphabetically
  table.sort(priority_plugins, function(a, b)
    if a.plugin.priority ~= b.plugin.priority then
      return a.plugin.priority > b.plugin.priority
    end
    if a.plugin.load_order and b.plugin.load_order then
      return a.plugin.load_order < b.plugin.load_order
    end
    return string.lower(a.name) < string.lower(b.name)
  end)

  -- Normal plugins: sort by load order, then alphabetically
  table.sort(normal_plugins, function(a, b)
    if a.plugin.load_order and b.plugin.load_order then
      return a.plugin.load_order < b.plugin.load_order
    end
    return string.lower(a.name) < string.lower(b.name)
  end)

  -- Lazy plugins: sort by load order, then alphabetically
  table.sort(lazy_plugins, function(a, b)
    if a.plugin.load_order and b.plugin.load_order then
      return a.plugin.load_order < b.plugin.load_order
    end
    return string.lower(a.name) < string.lower(b.name)
  end)

  -- Combine all categories in the desired order
  local sorted = {}
  for _, entry in ipairs(priority_plugins) do
    table.insert(sorted, entry)
  end
  table.insert(sorted, { type = 'separator' })
  for _, entry in ipairs(normal_plugins) do
    table.insert(sorted, entry)
  end
  table.insert(sorted, { type = 'separator' })
  for _, entry in ipairs(lazy_plugins) do
    table.insert(sorted, entry)
  end
  table.insert(sorted, { type = 'separator' })

  cache.sorted_plugins = sorted
  cache.last_update = now
  return sorted
end

---Generate dashboard content
---@param plugins table<string, PlugmanPlugin>
---@param config table Configuration
---@return table Lines
function M.generate_content(plugins, config)
  local lines = {}
  local icons = config.ui.icons
  local stats = get_stats(plugins)

  -- Header
  table.insert(lines, "                     🔌                   ")
  table.insert(lines, "  ╭──────────────────────────────────────╮")
  table.insert(lines, "  │               Plugman                │")
  table.insert(lines, "  │      Plugin Manager for Neovim       │")
  table.insert(lines, "  ╰──────────────────────────────────────╯")
  table.insert(lines, "                     🔌                   ")

  -- Stats
  table.insert(lines, string.format("  📊 Stats: %d total (%d priority, %d normal, %d lazy), %d installed, %d added, %d loaded",
    stats.total, stats.priority, stats.normal, stats.lazy, stats.installed, stats.added, stats.loaded))
  table.insert(lines, "")
  table.insert(lines, "  ─────────────────────────────────────")
  table.insert(lines, "")

  -- After the stats section and before the plugin list:
  table.insert(lines, "")
  table.insert(lines, "  🔗 Dependencies:")
  table.insert(lines, "")

  -- Create a map of dependencies
  local dependency_map = {}
  for name, plugin in pairs(plugins) do
    if plugin.depends then
      for _, dep in ipairs(plugin.depends) do
        if not dependency_map[dep] then
          dependency_map[dep] = {
            name = dep,
            dependents = {},
            plugin = plugins[dep]
          }
        end
        table.insert(dependency_map[dep].dependents, name)
      end
    end
  end

  -- Sort and display dependencies
  local sorted_deps = {}
  for _, dep in pairs(dependency_map) do
    table.insert(sorted_deps, dep)
  end
  table.sort(sorted_deps, function(a, b) return a.name < b.name end)

  for _, dep in ipairs(sorted_deps) do
    local dep_plugin = dep.plugin
    local status_icon = dep_plugin and dep_plugin:is_installed() and icons.installed or icons.not_installed
    local add_icon = dep_plugin and dep_plugin.added and icons.added or icons.not_added
    
    local line = string.format("  %s %s %s",
      status_icon, add_icon, dep.name)
    
    -- Add dependents
    if #dep.dependents > 0 then
      line = line .. string.format(" [used by: %s]", table.concat(dep.dependents, ", "))
    end
    
    -- Add load order if available
    if dep_plugin and dep_plugin.load_order then
      line = line .. string.format(" (order: %d)", dep_plugin.load_order)
    end
    
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, "  ─────────────────────────────────────")
  table.insert(lines, "")

  -- Plugin list
  local sorted_plugins = sort_plugins(plugins)
  local current_section = nil

  for _, item in ipairs(sorted_plugins) do
    if item.type == 'separator' then
      table.insert(lines, "  ─────────────────────────────────────")
      table.insert(lines, "")
    else
      local name = item.name
      local plugin = item.plugin

      -- Add section headers
      if plugin.priority and plugin.priority > 0 and current_section ~= 'priority' then
        current_section = 'priority'
        table.insert(lines, "  🚀 Priority Plugins:")
        table.insert(lines, "")
      elseif plugin.priority and plugin.priority == 0 and not plugin.lazy and current_section ~= 'normal' then
        current_section = 'normal'
        table.insert(lines, "  ⚡ Normal Plugins:")
        table.insert(lines, "")
      elseif plugin.lazy and current_section ~= 'lazy' then
        current_section = 'lazy'
        table.insert(lines, "  💤 Lazy Plugins:")
        table.insert(lines, "")
      end

      local status_icon = plugin:is_installed() and icons.installed or icons.not_installed
      local add_icon = plugin.added and icons.added or icons.not_added
      local load_icon = plugin.loaded and icons.loaded or icons.not_loaded
      local lazy_icon = plugin.lazy and icons.lazy or plugin.lazy == false and icons.not_lazy
      local priority_icon = plugin.priority > 0 and icons.priority or " "

      local line = string.format("  %s %s %s %s %s %s (order: %d)",
        status_icon, add_icon, load_icon, lazy_icon, priority_icon, name, plugin.load_order or 0)

      if plugin.priority > 0 then
        line = line .. string.format(" (priority: %d)", plugin.priority)
      end

      -- Add trigger information for lazy plugins
      if plugin.lazy then
        local triggers = {}
        if plugin.cmd then table.insert(triggers, "cmd") end
        if plugin.event then table.insert(triggers, "event") end
        if plugin.ft then table.insert(triggers, "ft") end
        if plugin.keys then table.insert(triggers, "keys") end
        if #triggers > 0 then
          line = line .. string.format(" [%s]", table.concat(triggers, ", "))
        end
      end

      table.insert(lines, line)
    end
  end

  -- Footer
  table.insert(lines, "")
  table.insert(lines, "  ─────────────────────────────────────")
  table.insert(lines, "")
  table.insert(lines, "  Keymaps:")
  table.insert(lines, "    <CR> - Show plugin details")
  table.insert(lines, "    i    - Install plugin")
  table.insert(lines, "    u    - Update plugin")
  table.insert(lines, "    d    - Remove plugin")
  table.insert(lines, "    r    - Reload plugin")
  table.insert(lines, "    U    - Update all")
  table.insert(lines, "    q    - Quit")
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
    highlight PlugmanSection guifg=#61AFEF gui=bold
    highlight PlugmanTrigger guifg=#56B6C2
  ]])
end

---Show plugin details
---@param plugin PlugmanPlugin
---@param name string Plugin name
---@param config table Configuration
---@return table Lines
function M.show_plugin_details(plugin, name, config)
  local lines = {}
  local icons = config.ui.icons

  -- Header
  table.insert(lines, string.format("  ╭─ %s Details ─╮", name))
  table.insert(lines, "  │")

  -- Status
  local status_icon = plugin.installed and icons.installed or icons.not_installed
  local load_icon = plugin.loaded and icons.loaded or icons.not_loaded
  local lazy_icon = plugin.lazy and icons.lazy or icons.not_lazy
  local priority_icon = plugin.priority > 0 and icons.priority or "  "

  table.insert(lines, string.format("  │ Status: %s %s %s %s",
    status_icon, load_icon, lazy_icon, priority_icon))
  table.insert(lines, "  │")

  -- Plugin Spec
  table.insert(lines, "  │ Specification:")
  for k, v in pairs(plugin) do
    if type(v) ~= 'function' and k ~= 'name' then
      local value = type(v) == 'table' and vim.inspect(v) or tostring(v)
      -- Format long values
      if #value > 50 then
        value = value:sub(1, 47) .. "..."
      end
      table.insert(lines, string.format("  │   %s: %s", k, value))
    end
  end

  -- Footer
  table.insert(lines, "  │")
  table.insert(lines, "  ╰──────────────────────╯")
  table.insert(lines, "")
  table.insert(lines, "  Press '<BS>' to return to plugin list")

  return lines
end

---Setup keymaps
---@param buf number Buffer handle
---@param win number Window handle
---@param manager PlugmanManager
function M.setup_keymaps(buf, win, manager)
  local opts = { buffer = buf, nowait = true, silent = true }
  local config = manager.config

  -- Quit
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, opts)

  -- Get plugin under cursor
  local function get_current_plugin()
    local line = vim.api.nvim_get_current_line()
    -- Match the plugin name from the line format
    local name = line:match("  [●○] [✓✗] [✓○] [💤 ] [⚡ ] ([%w%-%._]+)")
    if not name then
      -- Try matching from the details view
      name = line:match("  │   name: ([%w%-%._]+)")
    end
    return name and manager.plugins[name], name
  end

  -- Show plugin details
  vim.keymap.set('n', '<CR>', function()
    local plugin, name = get_current_plugin()
    if plugin then
      local details = M.show_plugin_details(plugin, name, config)
      vim.api.nvim_buf_set_option(buf, 'modifiable', true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, details)
      vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    end
  end, opts)

  -- Return to plugin list
  vim.keymap.set('n', '<BS>', function()
    -- Clear cache to force refresh
    cache.sorted_plugins = nil
    cache.stats = nil
    local lines = M.generate_content(manager:get_plugins(), config)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  end, opts)

  -- Install plugin
  vim.keymap.set('n', 'i', function()
    local plugin = get_current_plugin()
    if plugin and not plugin.installed then
      manager:install(plugin)
      -- Clear cache to force refresh
      cache.sorted_plugins = nil
      cache.stats = nil
      vim.cmd('redraw')
    end
  end, opts)

  -- Update plugin
  vim.keymap.set('n', 'u', function()
    local plugin = get_current_plugin()
    if plugin and plugin.installed then
      manager:update({ plugin.name })
      -- Clear cache to force refresh
      cache.sorted_plugins = nil
      cache.stats = nil
      vim.cmd('redraw')
    end
  end, opts)

  -- Remove plugin
  vim.keymap.set('n', 'd', function()
    local plugin = get_current_plugin()
    if plugin then
      manager:remove(plugin.name)
      -- Clear cache to force refresh
      cache.sorted_plugins = nil
      cache.stats = nil
      vim.cmd('redraw')
    end
  end, opts)

  -- Reload plugin
  vim.keymap.set('n', 'r', function()
    local plugin = get_current_plugin()
    if plugin and plugin.installed then
      manager:load(plugin)
      -- Clear cache to force refresh
      cache.sorted_plugins = nil
      cache.stats = nil
      vim.cmd('redraw')
    end
  end, opts)

  -- Update all
  vim.keymap.set('n', 'U', function()
    manager:update()
    -- Clear cache to force refresh
    cache.sorted_plugins = nil
    cache.stats = nil
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
