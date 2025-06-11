local M = {}

function M.check()
    local health = vim.health or require('health')

    health.report_start('Plugman Health Check')

    -- Check MiniDeps
    local has_minideps, minideps = pcall(require, 'mini.deps')
    if has_minideps then
        health.report_ok('MiniDeps is available')
    else
        health.report_error('MiniDeps is not available')
    end


    -- Check cache directory
    local cache_dir = vim.fn.stdpath('cache')
    if vim.fn.isdirectory(cache_dir) == 1 then
        health.ok('Cache directory exists: ' .. cache_dir)
    else
        health.error('Cache directory not found')
    end

    -- Check data directory
    local data_dir = vim.fn.stdpath('data')
    if vim.fn.isdirectory(data_dir) == 1 then
        health.ok('Data directory exists: ' .. data_dir)
    else
        health.error('Data directory not found')
    end


    -- Check plugin directory
    local plugins_dir = vim.fn.stdpath('config') .. '/lua/plugins'
    if vim.fn.isdirectory(plugins_dir) == 1 then
        health.report_ok('Plugins directory exists: ' .. plugins_dir)
    else
        health.report_warn('Plugins directory not found: ' .. plugins_dir)
    end

    -- Check modules directory
    local modules_dir = vim.fn.stdpath('config') .. '/lua/modules'
    if vim.fn.isdirectory(modules_dir) == 1 then
        health.report_ok('Modules directory exists: ' .. modules_dir)
    else
        health.report_warn('Modules directory not found: ' .. modules_dir)
    end

    -- Get Plugman state
    local plugman = require('plugman')
    if plugman.state.initialized then
        health.report_ok('Plugman is initialized')

        local total_plugins = vim.tbl_count(plugman.state.plugins)
        local loaded_plugins = 0

        for _, plugin in pairs(plugman.state.plugins) do
            if plugin.loaded then
                loaded_plugins = loaded_plugins + 1
            end
        end

        health.report_info(string.format('Total plugins: %d, Loaded: %d', total_plugins, loaded_plugins))
    else
        health.report_warn('Plugman is not initialized')
    end

    -- Check logger
    local logger = require('plugman.utils.logger')
    if logger then
        health.ok('Logger is available')
    else
        health.error('Logger not found')
    end

    -- Check cache system
    local cache = require('plugman.core.cache')
    if cache then
        health.ok('Cache system is available')
    else
        health.error('Cache system not found')
    end

    -- Check event system
    local events = require('plugman.core.events')
    if events then
        health.ok('Event system is available')
    else
        health.error('Event system not found')
    end
end

return M
