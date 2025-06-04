--Start-of-file--
local M = {}

-- Dependencies
local utils = require("plugman.utils")
local logger = require('plugman.utils.logger')
local notify = require("plugman.utils.notify")
local mini_deps = require("plugman.core.bootstrap")

-- Constants
local SETUP_PHASES = {
    {
        name = 'init',
        condition = function(c) return c.init ~= nil end,
        action = function(c) c.init() end,
        timing = 'now'
    },
    {
        name = 'config',
        condition = function(c) return (c.config ~= nil) or (c.opts ~= nil) end,
        action = function(c)
            local merged_opts = M._merge_config(c)
            M._process_config(c, merged_opts)
        end,
        timing = 'dynamic'
    },
    {
        name = 'keys',
        condition = function(c) return c.keys ~= nil end,
        action = function(c) M._setup_keymaps(c) end,
        timing = 'later'
    },
    {
        name = 'post',
        condition = function(c) return c.post ~= nil end,
        action = function(c) c.post() end,
        timing = 'later'
    }
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
    return source:match('([^/]+)$')
end

local function validate_plugin(plugin)
    if not plugin.source then
        logger.error('Plugin missing required source field')
        return false
    end
    if not utils.is_valid_github_url(plugin.source) then
        logger.error(string.format('Invalid GitHub URL: %s', plugin.source))
        return false
    end
    return true
end

-- Configuration Functions
function M._merge_config(plugin)
    if not (plugin.config or plugin.opts) then return {} end

    local default_opts = type(plugin.opts) == 'table' and plugin.opts or {}
    local config_opts = type(plugin.config) == 'table' and plugin.config or {}

    return vim.tbl_deep_extend('force', default_opts, config_opts)
end

function M._process_config(plugin, merged_opts)
    if not plugin then return end

    if type(plugin.config) == 'function' then
        return plugin.config(plugin, merged_opts)
    elseif type(plugin.config) == 'boolean' then
        return plugin.config
    elseif type(plugin.config) == 'string' then
        return vim.cmd(plugin.config)
    elseif merged_opts then
        local mod_name = plugin.require or plugin.name
        local ok, mod = pcall(require, mod_name)
        if ok and mod.setup then
            return mod.setup(merged_opts)
        else
            logger.error(string.format('Failed to require plugin: %s', mod_name))
        end
    end
end

function M._setup_keymaps(plugin)
    if not plugin or not plugin.keys then return end

    local module_keys = plugin.keys
    if type(module_keys) ~= "table" and type(module_keys) ~= "function" then
        logger.error(string.format("Invalid keys format for %s", plugin.name))
        return
    end

    local keys = type(module_keys) == "function" and safe_pcall(module_keys) or module_keys
    if type(keys) ~= "table" then
        logger.error(string.format("Invalid keys format for %s", plugin.name))
        return
    end

    for _, keymap in ipairs(keys) do
        if type(keymap) == "table" and keymap[1] then
            local opts = {
                buffer = keymap.buffer,
                desc = keymap.desc,
                silent = keymap.silent ~= false,
                remap = keymap.remap,
                noremap = keymap.noremap ~= false,
                nowait = keymap.nowait,
                expr = keymap.expr,
            }
            for _, mode in ipairs(keymap.mode or { "n" }) do
                vim.keymap.set(mode, keymap[1], keymap[2], opts)
            end
        else
            logger.warn(string.format("Invalid keymap entry for %s", plugin.name))
        end
    end
end

-- Core Functions
function M.add_plugin(plugin)
    if not validate_plugin(plugin) then return false end

    return safe_pcall(function()
        logger.debug(string.format('Adding plugin to MiniDeps: %s', vim.inspect(plugin)))
        local deps_success, deps_err = pcall(mini_deps.add, {
            source = plugin.source,
            depends = plugin.depends,
            monitor = plugin.monitor,
            checkout = plugin.checkout,
            hooks = plugin.hooks,
        })

        if not deps_success then
            logger.error(string.format('Failed to add plugin to MiniDeps: %s', deps_err))
            notify.error(string.format('Failed to load %s', plugin.name))
            return false
        end
        return true
    end)
end

function M.load_plugin(Plugin)
    if not Plugin then return false end
    logger.debug(string.format('Loading plugin: %s (source: %s)', Plugin.name, Plugin.source))

    return safe_pcall(function()
        -- Handle dependencies
        if Plugin.depends then
            for _, dep in ipairs(Plugin.depends) do
                local dep_source = type(dep) == "string" and dep or dep[1]
                local dep_name = extract_plugin_name(dep_source)
                local Dep = require("plugman")._plugins[dep_name]
                if Dep then
                    M.ensure_dependency_loaded(Dep)
                else
                    logger.warn(string.format('Dependency not found: %s', dep_name))
                end
            end
        end

        -- Load plugin configuration
        M._load_plugin_config(Plugin)
        return true
    end)
end

function M._load_plugin_config(Plugin)
    if not (Plugin.config or Plugin.opts) then return end

    return safe_pcall(function()
        for _, phase in ipairs(SETUP_PHASES) do
            if phase.condition(Plugin) then
                local timing_fn = utils.get_timing_function(Plugin, phase)
                timing_fn(function()
                    utils.safe_pcall(phase.action, Plugin)
                    logger.debug(string.format("Phase %s completed for %s", phase.name, Plugin.name))
                end)
            end
        end
    end)
end

function M.ensure_dependency_loaded(Dep)
    if not Dep then return end
    
    local plugman = require('plugman')
    if plugman._loaded[Dep.name] or Dep.loaded then return end

    local ok = safe_pcall(M.load_plugin, Dep)
    if not ok then
        logger.warn(string.format('Dependency %s not loaded', Dep.name))
    end
end

function M.load_plugin_files(dir_path)
    if not dir_path or vim.fn.isdirectory(dir_path) == 0 then
        logger.warn(string.format('Invalid directory: %s', dir_path))
        return {}
    end

    local plugins = {}
    local files = vim.fn.glob(dir_path .. '/*.lua', false, true)
    logger.debug(string.format('Found %d files in %s', #files, dir_path))

    for _, file_path in ipairs(files) do
        local plugin_configs = safe_pcall(dofile, file_path)
        if plugin_configs then
            if type(plugin_configs[1]) == "string" then
                -- Single plugin config
                if utils.is_valid_github_url(plugin_configs[1]) then
                    plugin_configs.lazy = utils.to_boolean(plugin_configs.lazy)
                    plugin_configs.source = plugin_configs[1]
                    plugin_configs.name = plugin_configs.name or extract_plugin_name(plugin_configs[1])
                    table.insert(plugins, plugin_configs)
                end
            elseif type(plugin_configs) == 'table' then
                -- Multiple plugins config
                for _, plugin_config in ipairs(plugin_configs) do
                    if type(plugin_config[1]) == "string" and utils.is_valid_github_url(plugin_config[1]) then
                        plugin_config.lazy = utils.to_boolean(plugin_config.lazy)
                        plugin_config.source = plugin_config[1]
                        plugin_config.name = plugin_config.name or extract_plugin_name(plugin_config[1])
                        table.insert(plugins, plugin_config)
                    end
                end
            end
        end
    end

    logger.info(string.format('Loaded %d plugins from %s', #plugins, dir_path))
    return plugins
end

function M.load_all()
    local config_opts = require("plugman").opts
    if not config_opts.paths then
        logger.warn('No paths configured for plugin loading')
        return {}
    end

    local all_plugins = {}
    local plugins_path = string.format("%s/%s", 
        config_opts.paths.plugins_path, 
        config_opts.paths.plugins_dir or 'plugins'
    )

    local plugins = M.load_plugin_files(plugins_path)
    if #plugins > 0 then
        vim.list_extend(all_plugins, plugins)
    end

    logger.info(string.format('Total plugins ready: %d', #all_plugins))
    return all_plugins
end

return M
