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

---@class PlugmanPlugin
---@field source string Plugin source (GitHub repo, local path, etc.)
---@field name string Plugin name extracted from source
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

---Setup Plugman with user configuration
---@param opts? table Configuration options
function M.setup(opts)
    opts = vim.tbl_deep_extend("force", defaults, opts or {})
    logger.setup(opts.log_level or 'info')
    cache.setup(opts.cache or {})
    notify.setup(opts.notify or {})

    -- Bootstrap MiniDeps (install and setup)
    bootstrap.setup(opts.minideps or {})
    -- Setup autocmds for lazy loading
    events.setup()
    M._setup_done = true
    logger.info('Plugman initialized successfully')
    notify.info('Plugman ready!')
    M.setup_plugins(opts.paths)
end

function M.setup_plugins(paths)
    notify.info('Setting up plugins!')
    -- Load plugins from configured directories
    local all_plugins = loader.load_all(paths)
    print(vim.inspect(all_plugins))
    for _, plugin_spec in ipairs(all_plugins) do
        -- Format plugin spec and transform to PlugmanPlugin
        local Plugin = require("plugman.core").normalize_plugin(plugin_spec[1], plugin_spec, "plugin")
        if Plugin then
            M.add(Plugin)
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
    -- Store plugin
    M._plugins[plugin.name] = plugin
    -- Handle dependencies first
    if plugin.depends then
        for _, dep in ipairs(plugin.depends) do
            if not M._plugins[dep] and not M._loaded[dep] then
                local source = type(dep) == "string" and dep or dep[1]
                local Dep = require("plugman.core").normalize_plugin(source, dep, "dependent")
                -- Store dependency
                M._plugins[Dep.name] = Dep
                -- Load dependency
                local ok, _ = pcall(M._load_plugin_immediately, Dep.name, Dep)
                if not ok then
                    logger.warn(string.format('Dependency %s not loaded for %s', Dep.name, plugin.name))
                end
            end
            logger.info(string.format("Dependency %s already loaded", dep))
        end
    end

    -- Check if should lazy load
    if M._should_lazy_load(plugin) then
        M._lazy_plugins[plugin.name] = plugin
        M._setup_lazy_loading(plugin.name, plugin)
    else
        local ok, _ = pcall(M._load_plugin_immediately, plugin.name, plugin)
        if not ok then
            logger.warn(string.format('Plugin %s not loaded', plugin.name))
        end
    end

    logger.info(string.format('Added plugin: %s', plugin.name))
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
---@param name string Plugin name
function M._load_lazy_plugin(name)
    local opts = M._lazy_plugins[name]
    if not opts or M._loaded[name] then
        return
    end

    notify.info(string.format('Loading %s...', name))
    M._load_plugin_immediately(name, opts)
    M._lazy_plugins[name] = nil
end

---Load plugin immediately
---@param name string Plugin name
---@param opts PlugmanPlugin Plugin options
function M._load_plugin_immediately(name, opts)
    if M._loaded[name] then
        return
    end

    local ok, _ = pcall(function() loader.load_plugin(name, opts) end)

    if not ok then
        logger.warn(string.format("Plugin %s did not load"))
    end

    M._loaded[name] = true
    logger.info(string.format('Loaded plugin: %s', name))

    -- Cache the loaded state
    cache.set_plugin_loaded(name, true)
end

---Setup lazy loading for a plugin
---@param name string Plugin name
---@param opts PlugmanPlugin Plugin options
function M._setup_lazy_loading(name, opts)
    -- Event-based loading
    if opts.event then
        local events_list = type(opts.event) == 'table' and opts.event or { opts.event }
        for _, event in ipairs(events_list) do
            events.on_event(event, function()
                M._load_lazy_plugin(name)
            end)
        end
    end

    -- Filetype-based loading
    if opts.ft then
        local filetypes = type(opts.ft) == 'table' and opts.ft or { opts.ft }
        for _, ft in ipairs(filetypes) do
            events.on_filetype(ft, function()
                M._load_lazy_plugin(name)
            end)
        end
    end

    -- Command-based loading
    if opts.cmd then
        local commands = type(opts.cmd) == 'table' and opts.cmd or { opts.cmd }
        for _, cmd in ipairs(commands) do
            events.on_command(cmd, function()
                M._load_lazy_plugin(name)
            end)
        end
    end

    -- Key-based loading
    if opts.keys then
        events.on_keys(opts.keys, function()
            M._load_lazy_plugin(name)
        end)
    end
end

---Check if plugin should lazy load
---@param opts PlugmanPlugin Plugin options
---@return boolean
function M._should_lazy_load(opts)
    if opts.lazy == false then
        return false
    end

    return opts.lazy or opts.event ~= nil or opts.ft ~= nil or opts.cmd ~= nil or opts.keys ~= nil
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
