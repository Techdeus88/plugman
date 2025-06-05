local M = {}

---Check Plugman health
function M.check()
    local health = vim.health or require('health')
    if not health then
        vim.notify('Health check module not available', vim.log.levels.ERROR)
        return
    end

    health.start('Plugman Health Check')

    -- Check MiniDeps
    local has_minideps, minideps = pcall(require, 'mini.deps')
    if has_minideps then
        health.ok('MiniDeps is available')
    else
        health.error('MiniDeps not found', 'Please install mini.deps')
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
    local plugin_dir = data_dir .. '/site/pack/deps/start'
    if vim.fn.isdirectory(plugin_dir) == 1 then
        health.ok('Plugin directory exists: ' .. plugin_dir)
    else
        health.warn('Plugin directory not found, will be created on first use')
    end

    -- Check loaded plugins
    local plugman = require('plugman')
    if not plugman then
        health.error('Plugman module not found')
        return
    end

    local loaded_count = #plugman.loaded()
    local total_count = #plugman.list()
    local lazy_count = #plugman.lazy()

    health.info(string.format('Plugins: %d loaded, %d total', loaded_count, total_count))
    if lazy_count > 0 then
        health.info(string.format('%d plugins are lazy-loaded', lazy_count))
    end

    -- Check for failed plugins
    local failed_count = 0
    for name, status in pairs(plugman.status()) do
        if not status.loaded and not status.lazy then
            failed_count = failed_count + 1
        end
    end
    if failed_count > 0 then
        health.warn(string.format('%d plugins failed to load', failed_count))
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
