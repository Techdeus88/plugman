
-- Dependencies
require("plugman.core.store").init()
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
    Store.start = Store.start == 0 and vim.uv.hrtime() or Store.start
    logger.debug('Starting Plugman setup')

    opts = vim.tbl_deep_extend("force", defaults, opts or {})
    logger.debug(string.format('Setup options: %s', vim.inspect(opts)))

    -- Initialize components
    logger.setup(opts.log_level or 'info')
    cache.setup(opts.cache or {})
    notify.setup(opts.notify or {})
    bootstrap.setup(opts.minideps or {})
    event_manager.setup()

    Store.setup_done = true
    Store.opts = opts
    logger.info('Plugman initialized successfully')

    -- Load plugins
    logger.debug('Starting plugin setup')
    local setup_res = M.setup_plugins()
    if not setup_res then
        logger.error(string.format("%s plugins failed to load. Fix now!", #Store._failed_plugins))
    end
end

function M.setup_plugins()
    logger.debug("Setting up plugins")

    local all_plugin_specs = loader.load_all(M.opts)
    if not all_plugin_specs or #all_plugin_specs == 0 then
        logger.error('No plugins found to load')
        return
    end

    M.pre_register_plugins(all_plugin_specs)

    -- Use a single consistent approach
    local results = M.handle_all_plugins(Store._priority_plugins)

    for name, response in pairs(results) do
        Store._loaded[name] = response
        if not response.result then
            logger.error(string.format('Failed to load plugin: %s', name))
            table.insert(Store._failed_plugins, name)
        end
    end

    return #Store._failed_plugins == 0
end

function M.pre_register_plugins(plugin_specs)
    for _, plugin_spec in ipairs(plugin_specs) do
        if not plugin_spec then
            logger.error('Received nil plugin specification')
            goto continue
        end
        -- Pre-register plugin (format)
        local Plugin = M.pre_register_plugin(plugin_spec)
        if Plugin and Plugin.name then
            -- Store formatted Plugin
            Store._plugins[Plugin.name] = Plugin
            -- Store plugin by loading strategy
            if Plugin.priority ~= nil or Plugin.lazy == false then
                Store._priority_plugins[Plugin.name] = Plugin
            else
                Store._lazy_plugins[Plugin.name] = Plugin
            end
        else
            logger.error(string.format('Failed to register plugin: %s', vim.inspect(plugin_spec)))
        end
        ::continue::
    end
end

function M.pre_register_plugin(plugin_spec)
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
    if Store._plugins[name] then
        logger.warn(string.format('Plugin %s already registered', name))
        return Store._plugins[name]
    end

    local Plugin = core.normalize_plugin(source, plugin_spec, "plugin")
    if not Plugin then
        logger.error(string.format('Failed to normalize plugin: %s', vim.inspect(plugin_spec)))
        return nil
    end

    return Plugin
end

function M.handle_all_plugins(Plugins)
    local results = {}
    for name, Plugin in pairs(Plugins) do
        local res = loader.add_plugin(Plugin)
        if not res then
            logger.error("Plugin did not load" .. name)
        end
        results[name] = res
    end
    return results
end

function M.handle_priority_plugins(Plugins)
    local sorted_plugins = loader._sort_priority_plugins(Plugins)
    local results = {}
    for _, plugin_data in ipairs(sorted_plugins) do
        local sorted_plugin = plugin_data.opts
        if not sorted_plugin then
            logger.error(string.format('No plugin found for name: %s', sorted_plugin.name))
            results[sorted_plugin.name] = { result = false, type = "priority" }
            goto continue
        end

        local registered, _ = pcall(M.register_plugin, sorted_plugin)
        if not registered then
            logger.warn("Plugin not registered" .. sorted_plugin.name)
        end
        local success = loader._load_priority_plugin(sorted_plugin)
        if not success then
            logger.error(string.format('Error processing plugin %s: %s', sorted_plugin.name, tostring(success)))
        else
            sorted_plugin:has_loaded()
            logger.info(string.format('Plugin: %s registered and loaded', sorted_plugin.name))
        end
        results[sorted_plugin.name] = { result = success, type = "priority" }
        ::continue::
    end
    return results
end

function M.handle_lazy_plugins(Plugins)
    local results = {}
    for name, Plugin in pairs(Plugins) do
        if not Plugin then
            logger.error(string.format('No plugin found for name: %s', name))
            results[name] = { result = false, type = "lazy" }
            goto continue
        end

        -- -- Ensure plugin has proper configuration
        -- if (Plugin.opts == nil) and (Plugin.config == nil) then
        --     Plugin.opts = {}
        --     Plugin.config = function()
        --         local mod_name = Plugin.require or Plugin.name
        --         local ok, mod = pcall(require, mod_name)
        --         if ok and mod.setup then
        --             return mod.setup(Plugin.opts)
        --         end
        --     end
        -- end


        local registered, _ = pcall(M.register_plugin, Plugin)
        if not registered then
            logger.warn("Plugin not registered" .. Plugin.name)
        end
        local load_lazy_now = loader._setup_lazy_loading(Plugin)
        if load_lazy_now then
            local success = loader._load_lazy_plugin(Plugin)
            if not success then
                logger.error(string.format('Error processing plugin %s: %s', name, tostring(success)))
            else
                Plugin:has_loaded()
                logger.info(string.format('Plugin: %s added and setup for loading', name))
            end
            results[name] = { result = success, type = "lazy" }
        else
            logger.info("Plugin loaded via evt, ft, or cmd" .. Plugin.name)
        end
        ::continue::
    end
    return results
end

function M.register_plugin(Plugin)
    if not Plugin then
        logger.error('Attempted to register nil plugin')
        return nil
    end

    if type(Plugin) ~= 'table' then
        logger.error(string.format('Invalid plugin type: %s', type(Plugin)))
        return nil
    end

    local success, result = pcall(function()
        return M.handle_add(Plugin)
    end)

    if not success then
        logger.error(string.format('Error registering plugin: %s', tostring(result)))
        return nil
    end
    return success
end

function M.handle_add(Plugin)
    if not Plugin.name then
        logger.error('Plugin missing required name field')
        return
    end
    logger.debug(string.format('Adding plugin: %s', Plugin.name))

    -- Add plugin
    if Plugin.register and Plugin.type == "plugin" then
        local add_ok = safe_pcall(loader.add_plugin, Plugin.register)
        if add_ok then
            if type(Plugin.has_added) == 'function' then
                Plugin:has_added()
            else
                logger.warn(string.format('Plugin %s missing has_added method', Plugin.name))
            end
        end
    else
        logger.error(string.format('Plugin %s missing register configuration', Plugin.name))
    end

    -- Handle dependencies
    if Plugin.depends then
        M._handle_dependencies(Plugin)
    end
end

function M._handle_dependencies(Plugin)
    if not Plugin or not Plugin.depends then
        return
    end

    for _, dep in ipairs(Plugin.depends) do
        local dep_source = type(dep) == "string" and dep or dep[1]
        if not dep_source then
            logger.error(string.format('Invalid dependency for plugin %s', Plugin.name))
            goto continue
        end

        local dep_name = extract_plugin_name(dep_source)
        if not dep_name then
            logger.error(string.format('Could not extract name from dependency source: %s', dep_source))
            goto continue
        end

        if not Store._plugins[dep_name] and not Store._loaded[dep_name] then
            local Dep = core.normalize_plugin(dep_source, dep, "dependent")
            if Dep then
                Store._plugins[Dep.name] = Dep
                local ok = safe_pcall(loader.add_plugin, Dep)
                if not ok then
                    logger.warn(string.format('Dependency %s not loaded for %s',
                        Dep.name, Plugin.name))
                end
            else
                logger.error(string.format('Failed to normalize dependency %s for plugin %s',
                    dep_source, Plugin.name))
            end
        end

        ::continue::
    end
end

-- Plugin Management Functions
function M.remove(name)
    if not Store._plugins[name] then
        logger.error(string.format('Plugin %s not found', name))
        return
    end

    local success = bootstrap.clean(name)
    if success then
        Store._plugins[name] = nil
        Store._lazy_plugins[name] = nil
        Store._loaded[name] = nil
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
        if not Store._plugins[name] then
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
            loaded = Store._loaded[name] or false,
            lazy = Store._lazy_plugins[name] ~= nil,
            config = Store._plugins[name]
        }
    end

    local status = {}
    for plugin_name, _ in pairs(Store._plugins) do
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
    vim.notify(table.concat({ report }, "\n"), vim.log.levels.INFO, {
        title = "Startup metrics",
        timeout = 10000 -- 10 seconds
    })
    -- vim.api.nvim_echo({ { report, "Normal" } }, true, {})
    return report
end

-- API Functions
M.list = function() return vim.tbl_keys(Store._plugins) end
M.loaded = function() return vim.tbl_keys(Store._loaded) end
M.lazy = function() return vim.tbl_keys(Store._lazy_plugins) end

-- Create user commands
vim.api.nvim_create_user_command("PlugmanStartupReport", M.show_startup_report, {})

return M
