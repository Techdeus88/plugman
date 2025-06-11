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

function Plugman.plugins_content()
    local plugins = {
        priority = Plugman._priority_plugins,
        now = Plugman._now_plugins,
        lazy = Plugman._lazy_plugins
    }
    local lines = {
        "All Plugins"
    }
    local total_plugins = 0
    for type, p in pairs(plugins) do
        local total_type_plugs = #p
        local title_line = string.format("----------%s plugins-----------", type)
        table.insert(lines, title_line)

        for i, plugin in ipairs(p) do
            local plugin_line = string.format("%s) %s", i, plugin.name)
            table.insert(lines, plugin_line)
            table.insert(lines, "----------------------")
        end
        local end_line = string.format("-------%s plugins--------", total_type_plugs)
        table.insert(lines, end_line)
        table.insert(lines, "----------------------")
        table.insert(lines, "----------------------")
        total_plugins = total_plugins + total_type_plugs
    end
    table.insert(lines, "----------------------")
    table.insert(lines, "----------------------")
    table.insert(lines, string.format("Total Plugins: %d", total_plugins))

    return lines
end

-- API Functions
Plugman.list = function() return vim.tbl_keys(Plugman._plugins) end
Plugman.loaded = function() return vim.tbl_keys(Plugman._loaded) end
Plugman.lazy = function() return vim.tbl_keys(Plugman._lazy_plugins) end

-- Create user commands
vim.api.nvim_create_user_command("PlugmanStartupReport", Plugman.show_startup_report, {})

return Plugman
