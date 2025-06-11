local M = {}



-- Core modules
local bootstrap = require("plugman.core.bootstrap")
local manager = require('plugman.core.manager')
local loader = require('plugman.core.loader')
local cache = require('plugman.core.cache')
local logger = require('plugman.utils.logger')
local notify = require('plugman.utils.notify')
local health = require('plugman.health')
local dashboard = require('plugman.ui.dashboard')

-- Plugman state
M.state = {
  initialized = false,
  plugins = {},
  loading_order = { priority = {}, normal = {}, lazy = {} },
  config = require('plugman.config.defaults')
}

-- Setup function
function M.setup(opts)
  opts = opts or {}
  M.state.config = vim.tbl_deep_extend('force', M.state.config, opts)
  -- Initialize MiniDeps
  local b_ok, _ = pcall(bootstrap.setup, M.state.config.minideps)
  if not b_ok then
    logger.warn("MiniDeps not rigght")
  end
  
  -- Initialize cache
  local c_ok, _ = pcall(cache.init, M.state.config.cache)
  if not c_ok then
    logger.warn("Cache not right")
  end
  -- Initialize logger
  logger.init(M.state.config.logging)
  
  -- Load plugins from modules/plugins directories
  M.load_plugin_specs()
  
  -- Setup loading strategy
  loader.setup(M.state)
  
  -- Load plugins based on strategy
  M.load_plugins()
  
  -- Setup commands
  M.setup_commands()
  
  -- Mark as initialized
  M.state.initialized = true
  
  logger.info("Plugman initialized successfully")
  notify.info("Plugman ready!")
end

-- Load plugin specifications from directories
function M.load_plugin_specs()
  local specs = {}
  
  -- Validate config paths
  if not M.state.config.paths or not M.state.config.paths.plugins_dir then
    logger.error("Invalid plugins directory configuration")
    return
  end
  
  -- Load from plugins directory
  local plugins_dir = string.format("%s/lua/%s", vim.fn.stdpath('config'), M.state.config.paths.plugins_dir)
  if vim.fn.isdirectory(plugins_dir) == 0 then
    logger.warn("Plugins directory not found: " .. plugins_dir)
    return
  end
  
  for _, file in ipairs(vim.fn.glob(plugins_dir .. '/*.lua', false, true)) do
    local name = vim.fn.fnamemodify(file, ':t:r')
    local ok, spec = pcall(require, 'plugins.' .. name)
    
    if ok then
      if type(spec) == 'table' then
        if spec[1] or spec.source then
          -- Validate spec has required fields
          if spec.source or (spec[1] and type(spec[1]) == 'string') then
            table.insert(specs, spec)
          else
            logger.warn("Invalid plugin spec in " .. name .. ": missing source")
          end
        else
          -- Handle array of specs
          for _, plugin_spec in ipairs(spec) do
            if type(plugin_spec) == 'table' and (plugin_spec.source or (plugin_spec[1] and type(plugin_spec[1]) == 'string')) then
              table.insert(specs, plugin_spec)
            else
              logger.warn("Invalid plugin spec in " .. name .. ": invalid spec format")
            end
          end
        end
      else
        logger.warn("Invalid plugin spec in " .. name .. ": not a table")
      end
    else
      logger.error("Failed to load plugin spec: " .. file .. " - " .. tostring(spec))
    end
  end
  
  -- Convert specs to PlugmanPlugin objects
  local PlugmanPlugin = require('plugman.core.plugin').PlugmanPlugin
  for _, spec in ipairs(specs) do
    local ok, plugin = pcall(PlugmanPlugin.new, spec)
    if ok and plugin.enabled then
      manager.add_plugin(M.state, plugin)
    else
      logger.warn("Failed to create plugin from spec: " .. vim.inspect(spec))
    end
  end
end

-- Load plugins based on loading strategy
function M.load_plugins()
  -- Load priority plugins first
  for _, plugin in ipairs(M.state.loading_order.priority) do
    loader.load_plugin(plugin)
  end
  
  -- Load normal (non-lazy) plugins
  for _, plugin in ipairs(M.state.loading_order.normal) do
    loader.load_plugin(plugin)
  end
  
  -- Setup lazy loading for lazy plugins
  for _, plugin in ipairs(M.state.loading_order.lazy) do
    loader.setup_lazy_loading(plugin)
  end
end

-- API function to add plugins dynamically
function M.add(source, opts)
  opts = opts or {}
  
  if type(source) == 'string' then
    opts.source = source
  else
    opts = source
  end
  
  local PlugmanPlugin = require('plugman.core.plugin')
  local plugin = PlugmanPlugin.new(opts)
  
  if plugin.enabled then
    manager.add_plugin(M.state, plugin)
    
    -- Install and load immediately if not lazy
    if not plugin.lazy then
      loader.load_plugin(plugin)
    else
      loader.setup_lazy_loading(plugin)
    end
    
    notify.info("Added plugin: " .. plugin.name)
  end
end

-- Setup commands
function M.setup_commands()
  vim.api.nvim_create_user_command('PlugmanDashboard', function()
    dashboard.open(M.state)
  end, { desc = 'Open Plugman dashboard' })
  
  vim.api.nvim_create_user_command('PlugmanInstall', function()
    manager.install_all(M.state)
  end, { desc = 'Install all plugins' })
  
  vim.api.nvim_create_user_command('PlugmanUpdate', function()
    manager.update_all(M.state)
  end, { desc = 'Update all plugins' })
  
  vim.api.nvim_create_user_command('PlugmanClean', function()
    manager.clean(M.state)
  end, { desc = 'Clean unused plugins' })
  
  vim.api.nvim_create_user_command('PlugmanHealth', function()
    health.check()
  end, { desc = 'Check Plugman health' })
  
  vim.api.nvim_create_user_command('PlugmanReload', function()
    M.reload()
  end, { desc = 'Reload Plugman' })
end

-- Reload function
function M.reload()
  -- Clear loaded modules
  for name, _ in pairs(package.loaded) do
    if name:match('^plugman%.') then
      package.loaded[name] = nil
    end
  end
  
  -- Re-setup
  M.setup(M.state.config)
  notify.info("Plugman reloaded!")
end

return M
