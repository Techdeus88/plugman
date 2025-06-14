local Events = require('plugman.core.events')
local Logger = require('plugman.utils.logger')

---@class PlugmanLoader
local Loader = {}
Loader.__index = Loader

---Create new loader
---@param manager PlugmanManager
---@param config table
---@return PlugmanLoader
function Loader.new(manager, config)
  ---@class PlugmanLoader
  local self = setmetatable({}, Loader)

  self.manager = manager
  self.config = config
  self.events = Events.new(self)

  return self
end

---Initialize loader
function Loader:init()
  self:setup_autocmds()
  self:setup_commands()

  -- Schedule optional initial install (add to disk) and non-optional add to current session
  vim.schedule(function()
    self:install_all()
  end)
  -- Schedule initial load
  vim.schedule(function()
    self:load_startup_plugins()
  end)
end

function Loader:install_all()
  local plugins = self.manager:get_plugins()
  for _, plugin in pairs(plugins) do
    if not plugin:is_installed() then
      self.manager:install(plugin)
    end
  end
end

---Load startup plugins
function Loader:load_startup_plugins()
  local plugins = self.manager:get_plugins()

  -- Get priority, normal (non-lazy), and lazy plugins
  local priority_plugins = {}
  local normal_plugins = {}
  local lazy_plugins = {}
  local plugin_deps = {}

  -- First pass: categorize plugins and build dependency graph
  for name, plugin in pairs(plugins) do
    if not plugin.enabled then
      goto continue
    end

    -- Build dependency graph
    if plugin.depends then
      plugin_deps[name] = plugin.depends
    end

    if plugin.priority > 0 then
      table.insert(priority_plugins, plugin)
    elseif plugin.lazy == false then
      table.insert(normal_plugins, plugin)
    else
      table.insert(lazy_plugins, plugin)
    end

    ::continue::
  end

  -- Sort priority plugins by priority (higher first)
  table.sort(priority_plugins, function(a, b)
    return a.priority > b.priority
  end)

  -- Load priority plugins first (these must be sequential)
  for _, plugin in ipairs(priority_plugins) do
    self.manager:load(plugin)
  end

  -- Group normal plugins by dependencies
  local independent_plugins = {}
  local dependent_plugins = {}

  for _, plugin in ipairs(normal_plugins) do
    if not plugin_deps[plugin.name] or #plugin_deps[plugin.name] == 0 then
      table.insert(independent_plugins, plugin)
    else
      table.insert(dependent_plugins, plugin)
    end
  end

  -- Load independent plugins in parallel
  if #independent_plugins > 0 then
    local load_tasks = {}
    for _, plugin in ipairs(independent_plugins) do
      table.insert(load_tasks, function()
        self.manager:load(plugin)
      end)
    end
    vim.schedule(function()
      for _, task in ipairs(load_tasks) do
        task()
      end
    end)
  end

  -- Load dependent plugins sequentially
  for _, plugin in ipairs(dependent_plugins) do
    self.manager:load(plugin)
  end

  -- Setup lazy loading for lazy plugins
  for _, plugin in ipairs(lazy_plugins) do
    self:setup_lazy_loading(plugin)
  end

  Logger.info("Startup loading completed")
end

---Setup lazy loading for plugin
---@param plugin PlugmanPlugin
function Loader:setup_lazy_loading(plugin)
  -- Event-based loading
  if plugin.event then
    self.events:on_event(plugin.event, function()
      self.manager:load(plugin)
    end)
  end

  -- Command-based loading
  if plugin.cmd then
    self.events:on_command(plugin.cmd, function()
      self.manager:load(plugin)
    end)
  end

  -- Filetype-based loading
  if plugin.ft then
    self.events:on_filetype(plugin.ft, function()
      self.manager:load(plugin)
    end)
  end

  -- Key-based loading
  if plugin.keys then
    self.events:on_keys(plugin.keys, function()
      self.manager:load(plugin)
    end)
  end

  -- Fallback: load on timer for truly lazy plugins
  if plugin.lazy == true and not (plugin.event or plugin.cmd or plugin.ft or plugin.keys) then
    vim.defer_fn(function()
      if not plugin.loaded then
        self.manager:load(plugin)
      end
    end, self.config.performance.lazy_time) -- 2 second delay default
  end
end

---Setup autocmds
function Loader:setup_autocmds()
  local group = vim.api.nvim_create_augroup('Plugman', { clear = true })

  -- Lazy load on events
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'PlugmanLazyLoad',
    callback = function(args)
      local plugin_name = args.data.plugin
      local plugin = self.manager.plugins[plugin_name]
      if plugin then
        self.manager:load(plugin)
      end
    end,
  })
end

---Setup commands
function Loader:setup_commands()
  -- Create placeholder commands for lazy-loaded plugins
  local plugins = self.manager:get_plugins()

  for _, plugin in pairs(plugins) do
    if plugin.cmd then
      local commands = type(plugin.cmd) == 'table' and plugin.cmd or { plugin.cmd }

      for _, cmd in ipairs(commands) do
        self:create_lazy_command(cmd, plugin)
      end
    end
  end
end

---Create lazy command
---@param cmd string Command name
---@param plugin PlugmanPlugin
function Loader:create_lazy_command(cmd, plugin)
  vim.api.nvim_create_user_command(cmd, function(opts)
    -- Load plugin first
    self.manager:load(plugin)

    -- Re-execute command
    vim.schedule(function()
      local cmd_line = cmd
      if opts.args and opts.args ~= '' then
        cmd_line = cmd_line .. ' ' .. opts.args
      end
      vim.cmd(cmd_line)
    end)
  end, {
    nargs = '*',
    complete = function(...)
      -- Load plugin for completion
      self.manager:load(plugin)
      return {}
    end,
  })
end

return Loader



-- local logger = require('plugman.utils.logger')
-- local notify = require('plugman.utils.notify')
-- local messages = require('plugman.utils.message_handler')

-- local M = {}

-- function M.setup(state)
--   -- Setup lazy loading timer
--   if #state.loading_order.lazy > 0 then
--     vim.defer_fn(function()
--       M.load_remaining_lazy_plugins(state)
--     end, 2000) -- 2 second delay for lazy plugins without triggers
--   end
-- end

-- -- Load a single plugin
-- function M.load_plugin(plugin, should_notify)
--   should_notify = should_notify or (plugin.state and plugin.state.config.notify.show_loading_notifications) or false
--   if plugin.loaded then return end

--   messages.plugin(plugin.name, 'INFO', "Loading plugin", { notify = should_notify })

--   -- Run init hook
--   if plugin.init then
--     local ok, err = pcall(plugin.init)
--     if not ok then
--       messages.plugin(plugin.name, 'ERROR', "Init hook failed: " .. err, { notify = should_notify })
--     end
--   end

--   -- Install with MiniDeps
--   local minideps = require('mini.deps')
--   local spec = plugin:get_minideps_spec()
--   minideps.add(spec)

--   -- Setup keymaps
--   plugin:setup_keymaps()

--   -- Handle configuration
--   if plugin.config or plugin.opts then
--     local merged_opts = M._merge_config(plugin)
--     M._process_config(plugin, merged_opts)
--   end

--   -- Run post hook
--   if plugin.post then
--     local ok, err = pcall(plugin.post)
--     if not ok then
--       messages.plugin(plugin.name, 'ERROR', "Post hook failed: " .. err, { notify = should_notify })
--     end
--   end

--   plugin.loaded = true
--   plugin.installed = true

--   messages.plugin(plugin.name, 'SUCCESS', "Plugin loaded", { notify = should_notify })
-- end

-- -- Setup lazy loading for a plugin
-- function M.setup_lazy_loading(plugin, should_notify)
--   should_notify = should_notify or (plugin.state and plugin.state.config.notify.show_loading_notifications) or false
--   messages.plugin(plugin.name, 'INFO', "Setting up lazy loading", { notify = should_notify })

--   -- Event-based loading
--   if plugin.event then
--     local events = type(plugin.event) == 'table' and plugin.event or { plugin.event }

--     for _, event in ipairs(events) do
--       vim.api.nvim_create_autocmd(event, {
--         callback = function()
--           M.load_plugin(plugin, should_notify)
--           return true -- Remove autocmd after first trigger
--         end,
--         desc = "Lazy load " .. plugin.name
--       })
--     end
--   end

--   -- Command-based loading
--   if plugin.cmd then
--     local commands = type(plugin.cmd) == 'table' and plugin.cmd or { plugin.cmd }

--     for _, cmd in ipairs(commands) do
--       vim.api.nvim_create_user_command(cmd, function(opts)
--         M.load_plugin(plugin, should_notify)
--         -- Re-execute the command
--         vim.cmd(cmd .. ' ' .. (opts.args or ''))
--       end, {
--         nargs = '*',
--         desc = "Lazy load " .. plugin.name
--       })
--     end
--   end

--   -- Filetype-based loading
--   if plugin.ft then
--     local filetypes = type(plugin.ft) == 'table' and plugin.ft or { plugin.ft }

--     vim.api.nvim_create_autocmd('FileType', {
--       pattern = filetypes,
--       callback = function()
--         M.load_plugin(plugin, should_notify)
--       end,
--       desc = "Lazy load " .. plugin.name
--     })
--   end

--   -- Key-based loading
--   if plugin.keys then
--     for _, keymap in ipairs(plugin.keys) do
--       if type(keymap) == 'table' then
--         local lhs = keymap[1]
--         local rhs = keymap[2]
--         local opts = vim.tbl_extend('force', { desc = plugin.name }, keymap.opts or {})

--         -- Create temporary keymap that loads plugin
--         vim.keymap.set(keymap.mode or 'n', lhs, function()
--           M.load_plugin(plugin, should_notify)
--           -- Execute the actual keymap
--           if type(rhs) == 'function' then
--             rhs()
--           else
--             vim.cmd(rhs)
--           end
--         end, opts)
--       end
--     end
--   end
-- end

-- -- Load remaining lazy plugins (fallback after timer)
-- function M.load_remaining_lazy_plugins(state)
--   for _, plugin in ipairs(state.loading_order.lazy) do
--     if not plugin.loaded and plugin.lazy == true then
--       M.load_plugin(plugin, false) -- Don't notify for background loading
--     end
--   end
-- end

-- return M
