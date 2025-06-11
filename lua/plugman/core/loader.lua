--Start-of-file--
local M = {}

-- Dependencies
local utils = require("plugman.utils")
local logger = require('plugman.utils.logger')
local notify = require("plugman.utils.notify")
local EventManager = require("plugman.core.events")
local bootstrap = require("plugman.core.bootstrap")
local cache = require("plugman.core.cache")

-- State
local start_time = vim.uv.hrtime()
local first_render = nil
local final_render = nil

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
    return source:match('([^/]+)$') or source
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
function M.load_all(opts)
    local plugins_dir = opts.paths and opts.paths.plugins_dir or "plugins"
    local plugins_path = opts.paths and opts.paths.plugins_path or vim.fn.stdpath('config') .. '/lua'
    local full_path = plugins_path .. '/' .. plugins_dir
    local plugins = {}

    if vim.fn.isdirectory(full_path) ~= 1 then
        return plugins
    end

    for _, file in ipairs(vim.fn.globpath(full_path, "*.lua", false, true)) do
        local ok, plugins_spec = pcall(dofile, file)
        if ok and type(plugins_spec) == "table" then
            -- Handle single spec file
            if type(plugins_spec[1]) == "string" then
                table.insert(plugins, plugins_spec)
                -- Handle multi-spec file
            else
                for _, spec in ipairs(plugins_spec) do
                    if type(spec) == "table" and type(spec[1]) == "string" then
                        table.insert(plugins, spec)
                    end
                end
            end
        end
    end

    return plugins
end

local function should_load_now(plugin)
    -- Plugins that should load immediately
    if plugin.priority then return true end
    if plugin.lazy == false then return true end
    if plugin.event or plugin.ft or plugin.cmd or plugin.lazy == true then return false end
    return true -- Default to now if no specific timing is set
end

function M.add_plugin(plugin)
    if not validate_plugin(plugin) then return false end

    logger.debug(string.format('Adding plugin to MiniDeps: %s', vim.inspect(plugin)))

    local timing_fn = should_load_now(plugin) and bootstrap.now or bootstrap.later

    timing_fn(function()
        -- Register with MiniDeps
        local deps_success, deps_err = pcall(bootstrap.add, plugin)
        if not deps_success then
            logger.error(string.format('Failed to add plugin to MiniDeps: %s', deps_err))
            notify.error(string.format('Failed to load %s', plugin.source))
            return false
        end
        plugin:has_added()

        -- Process all plugin configuration in one go
        M._process_plugin_config(plugin)

        return true
    end)
end

function M._process_plugin_config(plugin)
    -- Handle initialization
    if plugin.init then
        plugin.init()
    end

    -- Handle configuration
    if plugin.config or plugin.opts then
        local merged_opts = M._merge_config(plugin)
        M._process_config(plugin, merged_opts)
    end

    -- Handle keymaps
    if plugin.keys then
        M._setup_keymaps(plugin)
    end

    -- Handle post-configuration
    if plugin.post then
        plugin.post()
    end

    -- Mark plugin as loaded
    plugin:has_loaded()
end

function M._sort_priority_plugins(Plugins)
    local sorted_plugins = {}
    local final_sorted_plugins = {}
    for name, p_opts in pairs(Plugins) do
        table.insert(sorted_plugins, { name = name, opts = p_opts })
    end

    table.sort(sorted_plugins, function(a, b)
        local priority_a = a.opts.priority or 1000
        local priority_b = b.opts.priority or 1000
        return priority_a < priority_b
    end)

    for _, p in ipairs(sorted_plugins) do
        final_sorted_plugins[p.name] = p.opts
    end

    return final_sorted_plugins
end

function M._setup_lazy_loading(Plugin)
    logger.debug(string.format('Setting up lazy loading for %s', Plugin.name))
    local res_event
    local res_ft
    local res_cmd

    if Plugin.event then
        res_event = M.setup_event_loading(Plugin)
    end

    if Plugin.ft then
        res_ft = M.setup_filetype_loading(Plugin)
    end

    if Plugin.cmd then
        res_cmd = M.setup_command_loading(Plugin)
    end

    return not utils.to_boolean(res_event or res_ft or res_cmd)
end

function M.setup_event_loading(Plugin)
    if not Plugin.event then return false end

    local events_list = type(Plugin.event) == 'table' and Plugin.event or { Plugin.event }
    for _, event in ipairs(events_list) do
        EventManager:register_handler(event, {
            plugin_name = Plugin.name,
            handler = function(args)
                if Plugin.loaded then return end

                local bufnr = args.buf
                logger.debug(string.format("Event handler triggered: %s-%s-%s",
                    Plugin.name, event, bufnr))

                local ok, err = pcall(M._load_lazy_plugin, Plugin)
                if not ok then
                    logger.error(string.format('Error in event handler for %s: %s',
                        Plugin.name, err))
                    return
                end

                Plugin:has_loaded()
                logger.debug(string.format("Plugin successfully loaded (event): %s",
                    Plugin.name))
            end
        })
    end
    return true
end

function M.setup_filetype_loading(Plugin)
    if not Plugin.ft then return false end

    local filetypes = type(Plugin.ft) == 'table' and Plugin.ft or { Plugin.ft }
    for _, filetype in ipairs(filetypes) do
        EventManager:register_handler('FileType', {
            plugin_name = Plugin.name,
            ft = filetype,
            handler = function(args)
                if Plugin.loaded then return end

                local bufnr = args.buf
                local buf_ft = vim.bo[bufnr].filetype

                if buf_ft == filetype then
                    local ok, err = pcall(M._load_lazy_plugin, Plugin)
                    if not ok then
                        logger.error(string.format('Error in filetype handler for %s: %s',
                            Plugin.name, err))
                        return
                    end

                    Plugin:has_loaded()
                    logger.debug(string.format("Plugin successfully loaded (filetype): %s",
                        Plugin.name))
                end
            end
        })
    end
    return true
end

function M.setup_command_loading(Plugin)
    if not Plugin.cmd then return false end

    local commands = type(Plugin.cmd) == 'table' and Plugin.cmd or { Plugin.cmd }
    for _, cmd in ipairs(commands) do
        vim.api.nvim_create_user_command(cmd, function()
            if Plugin.loaded then return end

            local ok, err = pcall(M._load_lazy_plugin, Plugin)
            if not ok then
                logger.error(string.format('Error launching plugin via command %s: %s',
                    cmd, err))
                return
            end

            Plugin:has_loaded()
            logger.debug(string.format("Plugin successfully loaded (command): %s",
                Plugin.name))
            vim.cmd(cmd)
        end, { desc = 'Load plugin: ' .. Plugin.name })
    end
    return true
end

function M._load_priority_plugin(plugin)
    local priority_plugins = require("plugman")._priority_plugins
    if not priority_plugins[plugin.name] then return false end

    return safe_pcall(M._load_plugin_immediately(plugin))
end

function M._load_lazy_plugin(plugin)
    local lazy_plugins = require("plugman")._lazy_plugins
    if not lazy_plugins[plugin.name] then return false end

    return safe_pcall(M._load_plugin_immediately(plugin))
end

function M._load_plugin_immediately(plugin)
    logger.debug(string.format('Loading %s...', plugin.name))
    local loaded_plugins = require("plugman")._loaded

    if loaded_plugins[plugin.name] then
        logger.debug(string.format('Plugin %s already loaded', plugin.name))
        return true
    end

    logger.debug(string.format('Loading plugin immediately: %s', plugin.name))
    local ok = safe_pcall(M.load_plugin, plugin)

    if not ok then
        logger.warn(string.format("Plugin %s did not load", plugin.name))
        return false
    end

    loaded_plugins[plugin.name] = true
    cache.set_plugin_loaded(plugin.name, true)
    M._track_render()
    logger.info(string.format('Loaded plugin: %s', plugin.name))
    return true
end

function M.load_plugin(Plugin)
    if not Plugin then return false end
    logger.debug(string.format('Loading plugin: %s (source: %s)', Plugin.name, Plugin.source))

    return safe_pcall(function()
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
                    logger.debug(string.format("Phase %s completed for %s",
                        phase.name, Plugin.name))
                end)
            end
        end
    end)
end

-- Timing Functions
function M._track_render()
    if not first_render then
        first_render = vim.uv.hrtime()
    end
    final_render = vim.uv.hrtime()
end

---Generate a detailed startup report
---@return string Formatted report string
function M.generate_startup_report()
    local plugman = require("plugman")
    local total_time = (vim.uv.hrtime() - start_time) / 1e6
    local first_render_time = first_render and (first_render - start_time) / 1e6 or 0
    local final_render_time = final_render and (final_render - start_time) / 1e6 or 0

    local total_plugins = vim.tbl_count(plugman._plugins)
    local loaded_plugins = vim.tbl_count(plugman._loaded)
    local lazy_plugins = vim.tbl_count(plugman._lazy_plugins)

    local report = {
        "=== Plugman Startup Report ===",
        string.format("Total startup time: %.2f ms", total_time),
        string.format("First render: %.2f ms", first_render_time),
        string.format("Final render: %.2f ms", final_render_time),
        string.format("Plugins loaded: %d/%d", loaded_plugins, total_plugins),
        string.format("Lazy plugins: %d", lazy_plugins),
        "=== Plugin Details ==="
    }

    for name, plugin in pairs(plugman._plugins) do
        if plugin.load_time then
            table.insert(report, string.format("  %s: %s", name, plugin.load_time))
        end
    end

    return table.concat(report, "\n")
end

return M
