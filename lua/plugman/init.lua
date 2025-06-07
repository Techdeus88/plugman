---@field public  _plugins table<string, PlugmanPlugin>
---@field public  _lazy_plugins table<string, PlugmanPlugin>
---@field public  _loaded table<string, boolean>
---@field private _setup_done boolean

local M = {}
M._start = 0

-- Dependencies
local cache = require("plugman.core.cache")
local loader = require("plugman.core.loader")
local events = require("plugman.core.events")
local defaults = require("plugman.config.default")
local logger = require("plugman.utils.logger")
local notify = require("plugman.utils.notify")
local bootstrap = require("plugman.core.bootstrap")
local utils = require("plugman.utils")

-- State
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
    events.setup()

    M._setup_done = true
    M.opts = opts
    logger.info('Plugman initialized successfully')

    -- Load plugins
    logger.debug('Starting plugin setup')
    M.setup_plugins()
end

function M.setup_plugins()
    logger.debug("Setting up plugins")

    local all_plugins = loader.load_all()
    if not all_plugins then
        logger.error('Failed to load plugins')
        return
    end

    logger.debug(string.format('Loaded %d plugins from directories', #all_plugins))

    -- Register plugins first
    for _, plugin_spec in ipairs(all_plugins) do
        local success, err = pcall(M.register_plugin, plugin_spec)
        if not success then
            logger.error(string.format('Failed to register plugin: %s', err))
        end
    end
    local priority_plugins = require("plugman.utils").filter_plugins(M._plugins,
        function(p)
            return p.priority ~= nil or p.lazy == false
        end)
    local non_priority_plugins = require("plugman.utils").filter_plugins(M._plugins,
        function(p) return p.lazy or p.event ~= nil or p.ft ~= nil or p.cmd ~= nil or p.priority == nil end)

    -- Load plugins by priority
    local results = loader.load_by_priority(priority_plugins)
    local lazy_results = M.handle_lazy(non_priority_plugins)
    -- Handle results
    for name, success in pairs(results) do
        if not success then
            logger.error(string.format('Failed to load plugin: %s', name))
            M._loaded[name] = false
        else
            M._loaded[name] = true
        end
    end
end

function M.register_plugin(plugin_spec)
    local source = plugin_spec[1]
    if not source then
        logger.error('Plugin spec missing source: ' .. vim.inspect(plugin_spec))
        return nil
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

function M.setup_plugin(Plugin)
    if not Plugin then return end

    local ok = safe_pcall(M.handle_load, Plugin)
    if not ok then
        logger.error(string.format('Failed to load plugin: %s', Plugin.name))
    end
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
    local add_ok, _ = safe_pcall(loader.add_plugin, Plugin.register)
    if add_ok then
        Plugin:has_added()
    end

    -- Handle dependencies
    if Plugin.depends then
        M._handle_dependencies(Plugin)
    end
end

function M._handle_dependencies(Plugin)
    logger.debug(string.format('Processing dependencies for %s: %s', Plugin.name, vim.inspect(Plugin.depends)))

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
                    logger.warn(string.format('Dependency %s not loaded for %s', Dep.name, Plugin.name))
                end
            end
        else
            logger.debug(string.format("Dependency %s already loaded", dep))
        end
    end
end

function M.handle_lazy(plugins)
    for _, plugin in pairs(plugins) do
        M.handle_load(plugin)
    end

    M._load_lazy_plugins(M._lazy_plugins)
end

function M._load_lazy_plugins(plugins)
    for _, plugin in pairs(plugins) do
        M._load_lazy_plugin(plugin)
    end
end

function M.handle_load(Plugin)
    -- Load dependencies first
    if Plugin.depends then
        M._load_dependencies(Plugin)
    end

    -- Determine loading strategy
    M._setup_lazy_loading(Plugin)

    logger.info(string.format('Plugin: %s added and setup for loading', Plugin.name))
    return true
end

function M._load_dependencies(Plugin)
    for _, dep in ipairs(Plugin.depends) do
        local dep_source = type(dep) == "string" and dep or dep[1]
        local dep_name = extract_plugin_name(dep_source)
        local Dep = M._plugins[dep_name]

        if Dep then
            local ok = safe_pcall(M._load_plugin_immediately, Dep)
            if not ok then
                notify.error(string.format("Dependent %s did not load!", Dep.name))
            end
        end
    end
end

function M._setup_lazy_loading(plugin)
    logger.debug(string.format('Setting up lazy loading for %s', plugin.name))
    if plugin.lazy then
        M._lazy_plugins[plugin.name] = plugin
    end

    -- Event-based loading
    if plugin.event then
        local events_list = type(plugin.event) == 'table' and plugin.event or { plugin.event }
        for _, event in ipairs(events_list) do
            events.on_event(event, function() M._load_lazy_plugin(plugin) end)
        end
    end

    -- Filetype-based loading
    if plugin.ft then
        local filetypes = type(plugin.ft) == 'table' and plugin.ft or { plugin.ft }
        for _, ft in ipairs(filetypes) do
            events.on_filetype(ft, function() M._load_lazy_plugin(plugin) end)
        end
    end

    -- Command-based loading
    if plugin.cmd then
        local commands = type(plugin.cmd) == 'table' and plugin.cmd or { plugin.cmd }
        for _, cmd in ipairs(commands) do
            events.on_command(cmd, function() M._load_lazy_plugin(plugin) end)
        end
    end
end

function M._load_lazy_plugin(plugin)
    if not M._lazy_plugins[plugin.name] or M._loaded[plugin.name] then return end

    notify.info(string.format('Loading %s...', plugin.name))
    M._load_plugin_immediately(plugin)
    M._lazy_plugins[plugin.name] = nil
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
    end
    if type == "loaded" then
        M.loaded()
    end
    if type == "lazy" then
        M.lazy()
    end
end

-- API Functions
M.list = function() return vim.tbl_keys(M._plugins) end
M.loaded = function() return vim.tbl_keys(M._loaded) end
M.lazy = function() return vim.tbl_keys(M._lazy_plugins) end

return M
