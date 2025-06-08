--@class Plugman
---@field public _plugins table<string, PlugmanPlugin>
---@field public _lazy_plugins table<string, PlugmanPlugin>
---@field public _loaded table<string, boolean>
---@field private _setup_done boolean
---@field public opts table Configuration options
local M = {}

-- Dependencies
local cache = require("plugman.core.cache")
local loader = require("plugman.core.loader")
local event_manager = require("plugman.core.events")
local defaults = require("plugman.config.default")
local logger = require("plugman.utils.logger")
local notify = require("plugman.utils.notify")
local bootstrap = require("plugman.core.bootstrap")
local utils = require("plugman.utils")

-- State
M._start = 0
M._plugins = {}
M._lazy_plugins = {}
M._loaded = {}
M._setup_done = false
M.opts = nil

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
function M.setup(opts)
    M._start = M._start == 0 and vim.uv.hrtime() or M._start
    logger.debug('Starting Plugman setup')

    opts = vim.tbl_deep_extend("force", defaults, opts or {})
    logger.debug(string.format('Setup options: %s', vim.inspect(opts)))

    -- Initialize components
    logger.setup(opts.log_level or 'info')
    cache.setup(opts.cache or {})
    notify.setup(opts.notify or {})
    bootstrap.setup(opts.minideps or {})
    event_manager.setup()

    M._setup_done = true
    M.opts = opts
    logger.info('Plugman initialized successfully')

    -- Load plugins
    logger.debug('Starting plugin setup')
    M.setup_plugins()
end

function M.setup_plugins()
    logger.debug("Setting up plugins")
    print('DEBUG: Starting plugin setup')

    local all_plugins = loader.load_all(M.opts)
    print('DEBUG: Loaded plugins:', vim.inspect(all_plugins))
    
    if not all_plugins or #all_plugins == 0 then
        logger.error('No plugins found to load')
        print('DEBUG: No plugins found to load')
        return
    end

    logger.debug(string.format('Loaded %d plugins from directories', #all_plugins))
    print('DEBUG: Processing', #all_plugins, 'plugins')

    -- Register plugins first
    local registered_plugins = {}
    for _, plugin_spec in ipairs(all_plugins) do
        print('DEBUG: Registering plugin:', vim.inspect(plugin_spec))
        local plugin = M.register_plugin(plugin_spec)
        if plugin then
            registered_plugins[plugin.name] = plugin
            print('DEBUG: Successfully registered plugin:', plugin.name)
        else
            print('DEBUG: Failed to register plugin:', vim.inspect(plugin_spec))
        end
    end

    -- Separate plugins by loading strategy
    local priority_plugins = {}
    local lazy_plugins = {}

    for name, plugin in pairs(registered_plugins) do
        if plugin.priority ~= nil or plugin.lazy == false then
            priority_plugins[name] = plugin
            print('DEBUG: Added to priority plugins:', name)
        else
            lazy_plugins[name] = plugin
            print('DEBUG: Added to lazy plugins:', name)
        end
    end

    print('DEBUG: Priority plugins:', vim.inspect(priority_plugins))
    print('DEBUG: Lazy plugins:', vim.inspect(lazy_plugins))

    -- Load priority plugins first
    local results = loader._load_priority_plugins(priority_plugins)
    print('DEBUG: Priority plugin load results:', vim.inspect(results))

    -- Then load lazy plugins
    local lazy_results = loader._load_lazy_plugins(lazy_plugins)
    print('DEBUG: Lazy plugin load results:', vim.inspect(lazy_results))

    -- Merge and validate results
    local all_res = utils.deep_merge(results, lazy_results)
    local failed_plugins = {}

    for name, success in pairs(all_res) do
        if not success then
            logger.error(string.format('Failed to load plugin: %s', name))
            M._loaded[name] = false
            table.insert(failed_plugins, name)
            print('DEBUG: Failed to load plugin:', name)
        else
            M._loaded[name] = true
            print('DEBUG: Successfully loaded plugin:', name)
        end
    end

    -- Report results
    if #failed_plugins > 0 then
        logger.warn(string.format('Failed to load %d plugins: %s',
            #failed_plugins,
            table.concat(failed_plugins, ', ')
        ))
        print('DEBUG: Failed plugins:', table.concat(failed_plugins, ', '))
    end

    return #failed_plugins == 0
end

function M.register_plugin(plugin_spec)
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
    if M._plugins[name] then
        logger.warn(string.format('Plugin %s already registered', name))
        return M._plugins[name]
    end

    logger.debug(string.format('Normalizing plugin: %s', vim.inspect(plugin_spec)))
    local Plugin = require("plugman.core").normalize_plugin(source, plugin_spec, "plugin")

    if not Plugin then
        logger.error(string.format('Failed to normalize plugin: %s', vim.inspect(plugin_spec)))
        return nil
    end

    M.handle_add(Plugin)
    return Plugin
end

function M.handle_add(Plugin)
    if not M._setup_done then
        logger.error('Plugman not initialized. Call setup() first.')
        return
    end

    logger.debug(string.format('Adding plugin: %s', Plugin.name))

    -- Store plugin
    M._plugins[Plugin.name] = Plugin

    -- Register plugin
    local add_ok = safe_pcall(loader.add_plugin, Plugin.register)
    if add_ok then
        Plugin:has_added()
    end

    -- Handle dependencies
    if Plugin.depends then
        M._handle_dependencies(Plugin)
    end
end

function M._handle_dependencies(Plugin)
    logger.debug(string.format('Processing dependencies for %s: %s',
        Plugin.name, vim.inspect(Plugin.depends)))

    for _, dep in ipairs(Plugin.depends) do
        local dep_source = type(dep) == "string" and dep or dep[1]
        local dep_name = extract_plugin_name(dep_source)

        if not M._plugins[dep_name] and not M._loaded[dep_name] then
            logger.debug(string.format('Loading dependency: %s', dep_source))
            local Dep = require("plugman.core").normalize_plugin(dep_source, dep, "dependent")

            if Dep then
                M._plugins[Dep.name] = Dep
                local ok = safe_pcall(loader.add_plugin, Dep)
                if not ok then
                    logger.warn(string.format('Dependency %s not loaded for %s',
                        Dep.name, Plugin.name))
                end
            end
        else
            logger.debug(string.format("Dependency %s already loaded", dep))
        end
    end
end

-- Plugin Management Functions
function M.remove(name)
    if not M._plugins[name] then
        logger.error(string.format('Plugin %s not found', name))
        return
    end

    local success = bootstrap.clean(name)
    if success then
        M._plugins[name] = nil
        M._lazy_plugins[name] = nil
        M._loaded[name] = nil
        cache.remove_plugin(name)
        logger.info(string.format('Removed plugin: %s', name))
        notify.info(string.format('Removed %s', name))
    else
        logger.error(string.format('Failed to remove plugin: %s', name))
        notify.error(string.format('Failed to remove %s', name))
    end
end

function M.update(name)
    if name then
        if not M._plugins[name] then
            logger.error(string.format('Plugin %s not found', name))
            return
        end
        notify.info(string.format('Updating %s...', name))
        bootstrap.update(name)
    else
        notify.info('Updating all plugins...')
        bootstrap.update()
    end
end

function M.status(name)
    if name then
        return {
            name = name,
            loaded = M._loaded[name] or false,
            lazy = M._lazy_plugins[name] ~= nil,
            config = M._plugins[name]
        }
    end

    local status = {}
    for plugin_name, _ in pairs(M._plugins) do
        status[plugin_name] = M.status(plugin_name)
    end
    return status
end

-- UI Functions
function M.show()
    require('plugman.ui').show()
end

function M.show_one(type)
    if type == "list" then
        M.list()
    elseif type == "loaded" then
        M.loaded()
    elseif type == "lazy" then
        M.lazy()
    elseif type == "startup" then
        M.show_startup_report()
    end
end

function M.show_startup_report()
    local report = loader.generate_startup_report()
    vim.api.nvim_echo({ { report, "Normal" } }, true, {})
end

-- API Functions
M.list = function() return vim.tbl_keys(M._plugins) end
M.loaded = function() return vim.tbl_keys(M._loaded) end
M.lazy = function() return vim.tbl_keys(M._lazy_plugins) end

-- Create user commands
vim.api.nvim_create_user_command("PlugmanStartupReport", M.show_startup_report, {})

return M
