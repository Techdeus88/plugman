local M = {}

-- Core modules
local Manager = require('plugman.core.manager')
local Messages = require('plugman.utils.message_handler')
local Loader = require('plugman.core.loader')
local Logger = require('plugman.utils.logger')
local Notify = require('plugman.utils.notify')
local UI = require('plugman.ui')
local Config = require('plugman.config')

-- Global state
M.manager = nil
M.loader = nil
M.config = nil

---Initialize Plugman
---@param opts table Configuration options
function M.setup(opts)
  M.config = Config.setup(opts or {})
  -- Initialize core components
  Logger.setup(M.config.logging)
  Notify.setup(M.config.notify)
  Messages.init(M.config.messages)

  M.manager = Manager.new(M.config)
  M.loader = Loader.new(M.manager, M.config)
  -- Setup auto-discovery of plugins
  M._discover_plugins()
  -- Initialize loading sequence
  M.loader:init()

  Logger.info("Plugman initialized successfully")
  Notify.info("Plugman ready!")
end

---Add a plugin
---@param source string Plugin source (GitHub repo, local path, etc.)
---@param opts table Plugin options
function M.add(source, opts)
  if not M.manager then
    error("Plugman not initialized. Call setup() first.")
  end

  return M.manager:add(source, opts, "plugin")
end

---Remove a plugin
---@param name string Plugin name
function M.remove(name)
  if not M.manager then
    error("Plugman not initialized. Call setup() first.")
  end

  return M.manager:remove(name)
end

---Update plugins
---@param names table|nil Specific plugin names to update
function M.update(names)
  if not M.manager then
    error("Plugman not initialized. Call setup() first.")
  end

  return M.manager:update(names)
end

---Show UI
function M.show()
  if not M.manager then
    error("Plugman not initialized. Call setup() first.")
  end

  UI.show(M.manager)
end

---Get plugin status
---@param name string Plugin name
---@return table|nil Plugin status
function M.status(name)
  if not M.manager then
    return nil
  end

  return M.manager:status(name)
end

---Auto-discover plugins from configured directories
function M._discover_plugins()
  local plugins_dir = M.config.paths.plugins_dir
  local cache_key = 'plugin_discovery'
  local cache = M.manager.cache

  -- Try to get cached discovery results
  local cached = cache:get_plugin(cache_key)
  if cached and cached.timestamp and (vim.loop.now() - cached.timestamp) < 3600000 then -- 1 hour cache
    for _, spec in ipairs(cached.specs) do
      M.manager:add_spec(spec)
    end
    return
  end

  -- Build a map of directories to scan
  local dirs_to_scan = {}
  for _, dir in ipairs(plugins_dir) do
    local full_path = vim.fn.stdpath('config') .. '/lua/' .. dir:gsub('%.', '/')
    if vim.fn.isdirectory(full_path) == 1 then
      dirs_to_scan[full_path] = dir
    end
  end

  -- Collect all specs
  local specs = {}
  for full_path, module_path in pairs(dirs_to_scan) do
    -- Use glob to find all Lua files recursively
    local files = vim.fn.glob(full_path .. '/**/*.lua', false, true)

    for _, file in ipairs(files) do
      -- Convert file path to module path
      local relative_path = file:sub(#full_path + 2, -5) -- Remove .lua extension
      local module_name = module_path .. '.' .. relative_path:gsub('/', '.')

      local ok, plugins_spec = pcall(require, module_name)
      if ok then
        if type(plugins_spec) == "boolean" then
          goto continue
        end
        -- Handle single spec file
        if type(plugins_spec[1]) == "string" then
          table.insert(specs, plugins_spec)
          -- Handle multi-spec file
        else
          for _, spec in ipairs(plugins_spec) do
            if type(spec) == "table" and type(spec[1]) == "string" then
              table.insert(specs, spec)
            end
          end
        end
      else
        Logger.warn("Failed to load plugin spec from: " .. module_name)
      end
      ::continue::
    end
  end

  -- Cache the results
  cache:set_plugin(cache_key, {
    timestamp = vim.loop.now(),
    specs = specs
  })

  -- Add all specs to manager
  for _, spec in ipairs(specs) do
    M.manager:add_spec(spec)
  end
end

return M


-- local M = {}
-- -- Core modules
-- local bootstrap = require("plugman.core.bootstrap")
-- local manager = require('plugman.core.manager')
-- local loader = require('plugman.core.loader')
-- local cache = require('plugman.core.cache')
-- local logger = require('plugman.utils.logger')
-- local notify = require('plugman.utils.notify')
-- local health = require('plugman.health')
-- local dashboard = require('plugman.ui.dashboard')

-- -- Plugman state
-- M.state = {
--   initialized = false,
--   plugins = {},
--   loading_order = { priority = {}, normal = {}, lazy = {} },
--   config = require('plugman.config.defaults')
-- }

-- -- Setup function
-- function M.setup(opts)
--   opts = opts or {}
--   M.state.config = vim.tbl_deep_extend('force', M.state.config, opts)
--   -- Initialize MiniDeps
--   bootstrap.init(M.state.config.minideps)
--   -- Initialize cache
--   cache.init(M.state.config.cache)
--   -- Initialize logger
--   logger.init(M.state.config.logging)
--   -- Load plugins from modules/plugins directories
--   M.load_plugin_specs()
--   -- Setup loading strategy
--   loader.setup(M.state)
--   -- Load plugins based on strategy
--   M.load_plugins()
--   -- Setup commands
--   M.setup_commands()
--   -- Mark as initialized
--   M.state.initialized = true
--   messages.plugman('SUCCESS', "Plugman initialized successfully")
-- end

-- -- Load plugin specifications from directories
-- function M.load_plugin_specs()
--   local specs = {}

--   -- Validate config paths
--   if not M.state.config.paths or not M.state.config.paths.plugins_dir then
--     logger.error("Invalid plugins directory configuration")
--     return
--   end

--   -- Load from plugins directory
--   local plugins_dir = string.format("%s/lua/%s", vim.fn.stdpath('config'), M.state.config.paths.plugins_dir)
--   if vim.fn.isdirectory(plugins_dir) == 0 then
--     logger.warn("Plugins directory not found: " .. plugins_dir)
--     return
--   end

--   for _, file in ipairs(vim.fn.glob(plugins_dir .. '/*.lua', false, true)) do
--     local ok, plugins_spec = pcall(dofile, file)
--     if ok then


--   end


--   -- Convert specs to PlugmanPlugin objects
--   local PlugmanPlugin = require('plugman.core.plugin').PlugmanPlugin
--   for _, spec in ipairs(specs) do
--     local ok, plugin = pcall(PlugmanPlugin.new, spec)
--     if ok and plugin.enabled then
--       manager.add_plugin(M.state, plugin)
--     else
--       logger.warn("Failed to create plugin from spec: " .. vim.inspect(spec))
--     end
--   end
-- end

-- -- Load plugins based on loading strategy
-- function M.load_plugins()
--   -- Load priority plugins first
--   for _, plugin in ipairs(M.state.loading_order.priority) do
--     loader.load_plugin(plugin)
--   end

--   -- Load normal (non-lazy) plugins
--   for _, plugin in ipairs(M.state.loading_order.normal) do
--     loader.load_plugin(plugin)
--   end

--   -- Setup lazy loading for lazy plugins
--   for _, plugin in ipairs(M.state.loading_order.lazy) do
--     loader.setup_lazy_loading(plugin)
--   end
-- end

-- -- API function to add plugins dynamically
-- function M.add(source, opts)
--   opts = opts or {}

--   if type(source) == 'string' then
--     opts.source = source
--   else
--     opts = source
--   end

--   local PlugmanPlugin = require('plugman.core.plugin')
--   local plugin = PlugmanPlugin.new(opts)

--   if plugin.enabled then
--     manager.add_plugin(M.state, plugin)

--     -- Install and load immediately if not lazy
--     if not plugin.lazy then
--       loader.load_plugin(plugin)
--     else
--       loader.setup_lazy_loading(plugin)
--     end
--   end
-- end

-- -- Setup commands
-- function M.setup_commands()
--   vim.api.nvim_create_user_command('PlugmanDashboard', function()
--     dashboard.open(M.state)
--   end, { desc = 'Open Plugman dashboard' })

--   vim.api.nvim_create_user_command('PlugmanInstall', function()
--     manager.install_all(M.state)
--   end, { desc = 'Install all plugins' })

--   vim.api.nvim_create_user_command('PlugmanUpdate', function()
--     manager.update_all(M.state)
--   end, { desc = 'Update all plugins' })

--   vim.api.nvim_create_user_command('PlugmanClean', function()
--     manager.clean(M.state)
--   end, { desc = 'Clean unused plugins' })

--   vim.api.nvim_create_user_command('PlugmanHealth', function()
--     health.check()
--   end, { desc = 'Check Plugman health' })

--   vim.api.nvim_create_user_command('PlugmanReload', function()
--     M.reload()
--   end, { desc = 'Reload Plugman' })
-- end

-- -- Reload function
-- function M.reload()
--   -- Clear loaded modules
--   for name, _ in pairs(package.loaded) do
--     if name:match('^plugman%.') then
--       package.loaded[name] = nil
--     end
--   end

--   -- Re-setup
--   M.setup(M.state.config)
--   notify.info("Plugman reloaded!")
-- end

-- return M
