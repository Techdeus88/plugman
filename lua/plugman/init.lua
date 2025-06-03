---@class Plugman
---@field private _plugins table<string, PlugmanPlugin>
---@field private _lazy_plugins table<string, PlugmanPlugin>
---@field private _loaded table<string, boolean>
---@field private _setup_done boolean
local M = {}

local cache = require("plugman.core.cache")
local loader = require("plugman.core.loader")
local events = require("plugman.core.events")
local defaults = require("plugman.config.default")
local logger = require("plugman.utils.logger")
local notify = require("plugman.utils.notify")
local bootstrap = require("plugman.core.bootstrap")

M._plugins = {}
M._lazy_plugins = {}
M._loaded = {}
M._setup_done = false
M.opts = nil
---@class PlugmanPlugin
---@field source string Plugin source (GitHub repo, local path, etc.)
---@field name? string Plugin name extracted from source
---@field lazy? boolean Whether to lazy load
---@field event? string|string[] Events to trigger loading
---@field ft? string|string[] Filetypes to trigger loading
---@field cmd? string|string[] Commands to trigger loading
---@field keys? table|string[] Keymaps to create
---@field depends? string[] Dependencies
---@field hooks? table hooks for plugins during the pre,post stages
---@field monitor? string track new upcoming releases of the plugin
---@field checkout? string use a specific version of the plugin
---@field init? function Function to run before loading
---@field post? function Function to run after loading
---@field priority? number Load priority (higher = earlier)
---@field enabled? boolean Whether plugin is enabled
---@field require? string Require string for auto initialization and loading
---@field config? function|table Plugin configuration
---@field opts? table Plugin options

---Setup Plugman with user configuration
---@param opts? table Configuration options
function M.setup(opts)
    logger.debug('Starting Plugman setup')
    opts = vim.tbl_deep_extend("force", defaults, opts or {})
    logger.debug(string.format('Setup options: %s', vim.inspect(opts)))

    logger.setup(opts.log_level or 'info')
    cache.setup(opts.cache or {})
    notify.setup(opts.notify or {})

    -- Bootstrap MiniDeps (install and setup)
    logger.debug('Setting up MiniDeps')
    bootstrap.setup(opts.minideps or {})

    -- Setup autocmds for lazy loading
    logger.debug('Setting up events')
    events.setup()

    M._setup_done = true
    logger.info('Plugman initialized successfully')
    M.opts = opts
    logger.debug('Starting plugin setup')
    M.setup_plugins(opts.paths)
end

function M.setup_plugins()
    logger.debug(string.format("Setting up plugins"))

    -- Load plugins from configured directories
    local all_plugins = loader.load_all()
    logger.debug(string.format('Loaded %d plugins from directories', #all_plugins))
    logger.debug(string.format('Plugin specs: %s', vim.inspect(all_plugins)))
    if all_plugins ~= nil then
        for _, plugin_spec in ipairs(all_plugins) do
            logger.debug(string.format('Processing plugin spec: %s', vim.inspect(plugin_spec)))

            -- Format plugin spec and transform to PlugmanPlugin
            local source = plugin_spec[1] or plugin_spec.source
            if not source then
                logger.error('Plugin spec missing source: ' .. vim.inspect(plugin_spec))
                goto continue
            end

            -- Ensure plugin has required fields
            plugin_spec.source = source
            plugin_spec.name = plugin_spec.name or source:match('([^/]+)$')

            logger.debug(string.format('Normalizing plugin: %s', vim.inspect(plugin_spec)))
            local Plugin = require("plugman.core").normalize_plugin(source, plugin_spec, "plugin")
            if Plugin then
                logger.debug(string.format('Adding plugin: %s', Plugin.name))
                M.add(Plugin)
            else
                logger.error(string.format('Failed to normalize plugin: %s', vim.inspect(plugin_spec)))
            end
            ::continue::
        end
    end
end

--Add a plugin
---@param plugin PlugmanPlugin plugin
function M.add(plugin)
    if not M._setup_done then
        logger.error('Plugman not initialized. Call setup() first.')
        return
    end

    logger.debug(string.format('Adding plugin: %s', vim.inspect(plugin)))
    -- Store plugin
    M._plugins[plugin.name] = plugin
    logger.debug(string.format('Stored plugin: %s', plugin.name))

    -- Handle dependencies first
    if plugin.depends then
        logger.debug(string.format('Processing dependencies for %s: %s', plugin.name, vim.inspect(plugin.depends)))
        for _, dep in ipairs(plugin.depends) do
            local dep_source = type(dep) == "string" and dep or dep[1]
            local dep_name = dep_source:match('([^/]+)$')
            if not M._plugins[dep_name] and not M._loaded[dep_name] then
                logger.debug(string.format('Loading dependency: %s', dep_source))
                local Dep = require("plugman.core").normalize_plugin(dep_source, dep, "dependent")
                print(vim.inspect(Dep))
                if Dep then
                    -- Store dependency
                    M._plugins[Dep.name] = Dep
                    -- Load dependency
                    local ok, err = pcall(M._load_plugin_immediately, Dep)
                    if not ok then
                        logger.warn(string.format('Dependency %s not loaded for %s: %s', Dep.name, plugin.name, err))
                    end
                end
            else
                logger.debug(string.format("Dependency %s already loaded", dep))
            end
        end
    end

    -- Check if should lazy load
    local is_lazy = M._should_lazy_load(plugin)
    logger.debug(string.format('Plugin %s lazy loading: %s', plugin.name, is_lazy))

    if is_lazy then
        M._lazy_plugins[plugin.name] = plugin
        M._setup_lazy_loading(plugin)
        logger.debug(string.format('Plugin %s set up for lazy loading', plugin.name))
    else
        local ok, err = pcall(M._load_plugin_immediately, plugin)
        if not ok then
            logger.warn(string.format('Plugin %s not loaded: %s', plugin.name, err))
        end
    end

    logger.info(string.format('Plugin: %s added and setup for loading', plugin.name))
end

---Remove a plugin
---@param name string Plugin name
function M.remove(name)
    if not M._plugins[name] then
        logger.error(string.format('Plugin %s not found', name))
        return
    end

    -- Use MiniDeps to remove
    local success = MiniDeps.clean(name)

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

---Update plugins
---@param name? string Specific plugin name (updates all if nil)
function M.update(name)
    if name then
        if not M._plugins[name] then
            logger.error(string.format('Plugin %s not found', name))
            return
        end

        notify.info(string.format('Updating %s...', name))
        MiniDeps.update(name)
    else
        notify.info('Updating all plugins...')
        MiniDeps.update()
    end
end

---Load a lazy plugin
---@param plugin PlugmanPlugin Plugin
function M._load_lazy_plugin(plugin)
    local opts = M._lazy_plugins[plugin.name]
    if not opts or M._loaded[plugin.name] then
        return
    end

    notify.info(string.format('Loading %s...', plugin.name))
    M._load_plugin_immediately(plugin)
    M._lazy_plugins[plugin.name] = nil
end

---Load plugin immediately
---@param plugin PlugmanPlugin Plugin
function M._load_plugin_immediately(plugin)
    if M._loaded[plugin.name] then
        logger.debug(string.format('Plugin %s already loaded', plugin.name))
        return
    end

    logger.debug(string.format('Loading plugin immediately: %s', plugin.name))
    local ok, err = pcall(loader.load_plugin, plugin)

    if not ok then
        logger.warn(string.format("Plugin %s did not load: %s", plugin.name, err))
        return false
    end

    M._loaded[plugin.name] = true
    logger.info(string.format('Loaded plugin: %s', plugin.name))

    -- Cache the loaded state
    cache.set_plugin_loaded(plugin.name, true)
    return true
end

---Setup lazy loading for a plugin
---@param plugin PlugmanPlugin Plugin
function M._setup_lazy_loading(plugin)
    -- Event-based loading
    if plugin.event then
        local events_list = type(plugin.event) == 'table' and plugin.event or { plugin.event }
        for _, event in ipairs(events_list) do
            events.on_event(event, function()
                M._load_lazy_plugin(plugin)
            end)
        end
    end

    -- Filetype-based loading
    if plugin.ft then
        local filetypes = type(plugin.ft) == 'table' and plugin.ft or { plugin.ft }
        for _, ft in ipairs(filetypes) do
            events.on_filetype(ft, function()
                M._load_lazy_plugin(plugin)
            end)
        end
    end

    -- Command-based loading
    if plugin.cmd then
        local commands = type(plugin.cmd) == 'table' and plugin.cmd or { plugin.cmd }
        for _, cmd in ipairs(commands) do
            events.on_command(cmd, function()
                M._load_lazy_plugin(plugin)
            end)
        end
    end

    -- -- Key-based loading
    -- if plugin.keys then
    --     events.on_keys(plugin.keys, function()
    --         M._load_lazy_plugin(plugin)
    --     end)
    -- end
end

---Check if plugin should lazy load
---@param plugin PlugmanPlugin Plugin
---@return boolean
function M._should_lazy_load(plugin)
    local utils = require("plugman.utils")
    if plugin.lazy == false then
        return false
    end

    return utils.to_boolean(plugin.lazy) or utils.to_boolean(plugin.event) ~= nil or utils.to_boolean(plugin.ft ~= nil) or
        utils.to_boolean(plugin.cmd ~= nil)
end

---Validate plugin configuration
---@param source string Plugin source
---@param opts PlugmanPlugin Plugin options
---@return boolean
function M._validate_plugin(source, opts)
    if not source or source == '' then
        logger.error('Plugin source cannot be empty')
        return false
    end

    if opts.enabled == false then
        logger.info(string.format('Plugin %s is disabled', source))
        return false
    end

    return true
end

---Get plugin name from source
---@param source string Plugin source
---@return string
function M._get_plugin_name(source)
    return source:match('([^/]+)$') or source
end

---Get plugin status
---@param name? string Plugin name (returns all if nil)
---@return table
function M.status(name)
    if name then
        return {
            name = name,
            loaded = M._loaded[name] or false,
            lazy = M._lazy_plugins[name] ~= nil,
            config = M._plugins[name]
        }
    else
        local status = {}
        for plugin_name, _ in pairs(M._plugins) do
            status[plugin_name] = M.status(plugin_name)
        end
        return status
    end
end

---Show UI
function M.show()
    require('plugman.ui').show()
end

-- API functions
M.list = function() return vim.tbl_keys(M._plugins) end
M.loaded = function() return vim.tbl_keys(M._loaded) end
M.lazy = function() return vim.tbl_keys(M._lazy_plugins) end

return M
