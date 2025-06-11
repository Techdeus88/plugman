local M = {}



-- Core modules
local bootstrap = require("plugman.core.bootstrap")
local manager = require('plugman.core.manager')
local loader = require('plugman.core.loader')
local cache = require('plugman.core.cache')
local logger = require('plugman.utils.logger')
local notify = require('plugman.utils.notify')
local health = require('plugman.utils.health')
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
  bootstrap.setup(M.state.config.minideps)
  
  -- Initialize cache
  cache.init(M.state.config.cache)
  
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
  
  -- Load from plugins directory
  local plugins_dir = string.format("%s%s", vim.fn.stdpath('config') .. '/lua/', M.state.config.paths.plugins_dir)
  print(plugins_dir)
  if vim.fn.isdirectory(plugins_dir) == 1 then
    for _, file in ipairs(vim.fn.glob(plugins_dir .. '/*.lua', false, true)) do
      print(file)
      local name = vim.fn.fnamemodify(file, ':t:r')
      local ok, spec = pcall(require, 'plugins.' .. name)
      print(vim.inspect(spec))
      if ok then
        if type(spec) == 'table' then
          if spec[1] or spec.source then
            table.insert(specs, spec)
          else
            for _, plugin_spec in ipairs(spec) do
              table.insert(specs, plugin_spec)
            end
          end
        end
      else
        logger.error("Failed to load plugin spec: " .. file .. " - " .. spec)
      end
    end
  end

  print(vim.inspect(specs))
  -- Convert specs to PlugmanPlugin objects
  local PlugmanPlugin = require('plugman.core.plugin')
  for _, spec in ipairs(specs) do
    local plugin = PlugmanPlugin.new(spec)
    if plugin.enabled then
      manager.add_plugin(M.state, plugin)
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

---@class Plugman
---@field public _plugins table<string, PlugmanPlugin>
---@field public _priority_plugins table<string, PlugmanPlugin>
---@field public _lazy_plugins table<string, PlugmanPlugin>
---@field public _failed_plugins table<string, PlugmanPlugin>
---@field public _loaded table<string, boolean>
---@field private start number
---@field private setup_done boolean
---@field private opts table Configuration options
local Plugman = {}

-- Dependencies
local cache = require("plugman.core.cache")
local loader = require("plugman.core.loader")
local event_manager = require("plugman.core.events")
local defaults = require("plugman.config.default")
local logger = require("plugman.utils.logger")
local notify = require("plugman.utils.notify")
local bootstrap = require("plugman.core.bootstrap")
local utils = require("plugman.utils")
local core = require("plugman.core")

local M = {}
-- State
Plugman._plugins = {}
Plugman._start = 0
Plugman._priority_plugins = {}
Plugman._now_plugins = {}
Plugman._lazy_plugins = {}
Plugman._failed_plugins = {}
Plugman._loaded = {}
Plugman._setup_done = false
Plugman.opts = nil
-- Constants
local PLUGIN_STATES = {
    ADDED = 'added',
    LOADED = 'loaded',
    LOADING = 'loading'
}
-- Helper Functions
local function safe_pcall(fn, ...)
    local success, result = pcall(fn, ...)
    if not success then
        logger.error(string.format('Operation failed: %s', result))
        return nil
    end
    return result
end

local function extract_plugin_name(source)
    return source:match('([^/]+)$') or source
end

local function should_lazy_load(plugin)
    if plugin.lazy == false then return false end
    return utils.to_boolean(plugin.lazy) or
        utils.to_boolean(plugin.event) or
        utils.to_boolean(plugin.ft) or
        utils.to_boolean(plugin.cmd)
end

-- Core Functions
function Plugman.setup(opts)
    _G.Plugman = Plugman
    Plugman.start = Plugman.start == 0 and vim.uv.hrtime() or Plugman.start
    logger.debug('Starting Plugman setup')

    opts = vim.tbl_deep_extend("force", defaults, opts or {})
    logger.debug(string.format('Setup options: %s', vim.inspect(opts)))

    -- Initialize components
    logger.setup(opts.log_level or 'info')
    cache.setup(opts.cache or {})
    notify.setup(opts.notify or {})
    bootstrap.setup(opts.minideps or {})
    event_manager.setup()

    Plugman.setup_done = true
    Plugman.opts = opts
    logger.info('Plugman initialized successfully')

    -- Load plugins
    logger.debug('Starting plugin setup')
    local setup_res = Plugman.setup_plugins()
    if not setup_res then
        logger.error(string.format("%s plugins failed to load. Fix now!", #Plugman._failed_plugins))
    end
end

function Plugman.setup_plugins()
    logger.debug("Setting up plugins")

    local all_plugin_specs = loader.load_all(Plugman.opts)
    if not all_plugin_specs or #all_plugin_specs == 0 then
        logger.error('No plugins found to load')
        return
    end

    Plugman.pre_register_plugins(all_plugin_specs)

    -- Sort priority plugins but maintain the name->config mapping
    local sorted_plugins = loader._sort_priority_plugins(Plugman._priority_plugins)

    local priority_results = Plugman.handle_all_plugins(sorted_plugins)
    local now_results = Plugman.handle_all_plugins(Plugman._now_plugins)
    local lazy_results = Plugman.handle_all_plugins(Plugman._lazy_plugins)
    local results = utils.deep_merge(priority_results, lazy_results)

    for name, response in pairs(results) do
        Plugman._loaded[name] = response
        if not response then
            logger.error(string.format('Failed to load plugin: %s', name))
            table.insert(Plugman._failed_plugins, name)
        end
    end

    return #Plugman._failed_plugins == 0
end

function Plugman.pre_register_plugins(plugin_specs)
    for _, plugin_spec in ipairs(plugin_specs) do
        if not plugin_spec then
            logger.error('Received nil plugin specification')
            goto continue
        end
        -- Pre-register plugin (format)
        local Plugin = Plugman.pre_register_plugin(plugin_spec)
        if Plugin and Plugin.name then
            -- Store formatted Plugin
            Plugman._plugins[Plugin.name] = Plugin
            -- Store plugin by loading strategy
            if Plugin.priority ~= nil and type(Plugin.priority) == 'number' then
                Plugman._priority_plugins[Plugin.name] = Plugin
            elseif Plugin.lazy == false then
                Plugman._now_plugins[Plugin.name] = Plugin
            else
                Plugman._lazy_plugins[Plugin.name] = Plugin
            end
        else
            logger.error(string.format('Failed to register plugin: %s', vim.inspect(plugin_spec)))
        end
        ::continue::
    end
end

function Plugman.pre_register_plugin(plugin_spec)
    if not plugin_spec or not plugin_spec[1] then
        logger.error('Invalid plugin specification')
        return nil
    end

    local source = plugin_spec[1]
    if not utils.is_valid_github_url(source) then
        logger.error(string.format('Invalid plugin source: %s', source))
        return nil
    end

    -- Check if plugin is already registered
    local name = extract_plugin_name(source)
    if Plugman._plugins[name] then
        logger.warn(string.format('Plugin %s already registered', name))
        return Plugman._plugins[name]
    end

    local Plugin = core.normalize_plugin(source, plugin_spec, "plugin")
    if not Plugin then
        logger.error(string.format('Failed to normalize plugin: %s', vim.inspect(plugin_spec)))
        return nil
    end

    return Plugin
end

function Plugman.handle_all_plugins(Plugins)
    local results = {}
    for name, Plugin in pairs(Plugins) do
        local res = loader.add_plugin(Plugin)
        if not res then
            logger.error(string.format("Plugin did not load %s", name))
        end
        results[name] = res
    end
    return results
end

function Plugman.status(name)
    if name then
        return {
            name = name,
            loaded = Plugman._loaded[name] or false,
            lazy = Plugman._lazy_plugins[name] ~= nil,
            config = Plugman._plugins[name]
        }
    end

    local status = {}
    for plugin_name, _ in pairs(Plugman._plugins) do
        status[plugin_name] = Plugman.status(plugin_name)
    end
    return status
end

-- UI Functions
function Plugman.show()
    require('plugman.ui').show()
end

function Plugman.show_plugins()
    require('plugman.ui').show_plugin_detail()
end

function Plugman.show_one(type)
    if type == "list" then
        Plugman.list()
    elseif type == "loaded" then
        Plugman.loaded()
    elseif type == "lazy" then
        Plugman.lazy()
    elseif type == "startup" then
        Plugman.show_startup_report()
    end
end

function Plugman.show_startup_report()
    local report = loader.generate_startup_report()
    vim.notify(table.concat({ report }, "\n"), vim.log.levels.INFO, {
        title = "Startup metrics",
        timeout = 10000 -- 10 seconds
    })
    -- vim.api.nvim_echo({ { report, "Normal" } }, true, {})
    return report
end

-- API Functions
Plugman.list = function() return vim.tbl_keys(Plugman._plugins) end
Plugman.loaded = function() return vim.tbl_keys(Plugman._loaded) end
Plugman.lazy = function() return vim.tbl_keys(Plugman._lazy_plugins) end

-- Create user commands
vim.api.nvim_create_user_command("PlugmanStartupReport", Plugman.show_startup_report, {})

return Plugman
