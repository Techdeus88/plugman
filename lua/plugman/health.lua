local M = {}

---Check health
---@param manager PlugmanManager
---@return table Health report
function M.check(manager)
    local report = {
        status = 'ok',
        issues = {},
        warnings = {},
        info = {},
    }

    -- Check MiniDeps
    local ok, _ = pcall(require, 'mini.deps')
    if not ok then
        table.insert(report.issues, 'MiniDeps not found')
        report.status = 'error'
    else
        table.insert(report.info, 'MiniDeps available')
    end

    -- Check directories
    local dirs = {
        manager.config.paths.install_dir,
        manager.config.paths.cache_dir,
        manager.config.paths.snapshot_dir,
    }

    for _, dir in ipairs(dirs) do
        if vim.fn.isdirectory(dir) == 0 then
            table.insert(report.warnings, 'Directory does not exist: ' .. dir)
            if report.status == 'ok' then
                report.status = 'warning'
            end
        end
    end

    -- Check plugins
    local plugins = manager:get_plugins()
    local broken_plugins = {}

    for name, plugin in pairs(plugins) do
        if plugin.installed and not plugin.loaded then
            -- Try to load and see if it fails
            local ok, err = pcall(function()
                require(name)
            end)
            if not ok then
                table.insert(broken_plugins, name)
            end
        end
    end

    if #broken_plugins > 0 then
        table.insert(report.warnings, 'Plugins with issues: ' .. table.concat(broken_plugins, ', '))
        if report.status == 'ok' then
            report.status = 'warning'
        end
    end

    -- Cache stats
    local cache_stats = manager.cache:stats()
    table.insert(report.info, string.format('Cache: %d plugins, %d bytes',
        cache_stats.plugin_count, cache_stats.size))

    return report
end

---Format health report
---@param report table Health report
---@return string Formatted report
function M.format_report(report)
    local lines = {}

    table.insert(lines, '# Plugman Health Check')
    table.insert(lines, '')
    table.insert(lines, 'Status: ' .. report.status:upper())
    table.insert(lines, '')

    if #report.issues > 0 then
        table.insert(lines, '## Issues')
        for _, issue in ipairs(report.issues) do
            table.insert(lines, '- ❌ ' .. issue)
        end
        table.insert(lines, '')
    end

    if #report.warnings > 0 then
        table.insert(lines, '## Warnings')
        for _, warning in ipairs(report.warnings) do
            table.insert(lines, '- ⚠️  ' .. warning)
        end
        table.insert(lines, '')
    end

    if #report.info > 0 then
        table.insert(lines, '## Information')
        for _, info in ipairs(report.info) do
            table.insert(lines, '- ℹ️  ' .. info)
        end
        table.insert(lines, '')
    end

    return table.concat(lines, '\n')
end

return M

-- local M = {}

-- function M.check()
--     local health = vim.health or require('health')

--     health.report_start('Plugman Health Check')

--     -- Check MiniDeps
--     local has_minideps, minideps = pcall(require, 'mini.deps')
--     if has_minideps then
--         health.report_ok('MiniDeps is available')
--     else
--         health.report_error('MiniDeps is not available')
--     end


--     -- Check cache directory
--     local cache_dir = vim.fn.stdpath('cache')
--     if vim.fn.isdirectory(cache_dir) == 1 then
--         health.ok('Cache directory exists: ' .. cache_dir)
--     else
--         health.error('Cache directory not found')
--     end

--     -- Check data directory
--     local data_dir = vim.fn.stdpath('data')
--     if vim.fn.isdirectory(data_dir) == 1 then
--         health.ok('Data directory exists: ' .. data_dir)
--     else
--         health.error('Data directory not found')
--     end


--     -- Check plugin directory
--     local plugins_dir = vim.fn.stdpath('config') .. '/lua/plugins'
--     if vim.fn.isdirectory(plugins_dir) == 1 then
--         health.report_ok('Plugins directory exists: ' .. plugins_dir)
--     else
--         health.report_warn('Plugins directory not found: ' .. plugins_dir)
--     end

--     -- Check modules directory
--     local modules_dir = vim.fn.stdpath('config') .. '/lua/modules'
--     if vim.fn.isdirectory(modules_dir) == 1 then
--         health.report_ok('Modules directory exists: ' .. modules_dir)
--     else
--         health.report_warn('Modules directory not found: ' .. modules_dir)
--     end

--     -- Get Plugman state
--     local plugman = require('plugman')
--     if plugman.state.initialized then
--         health.report_ok('Plugman is initialized')

--         local total_plugins = vim.tbl_count(plugman.state.plugins)
--         local loaded_plugins = 0

--         for _, plugin in pairs(plugman.state.plugins) do
--             if plugin.loaded then
--                 loaded_plugins = loaded_plugins + 1
--             end
--         end

--         health.report_info(string.format('Total plugins: %d, Loaded: %d', total_plugins, loaded_plugins))
--     else
--         health.report_warn('Plugman is not initialized')
--     end

--     -- Check logger
--     local logger = require('plugman.utils.logger')
--     if logger then
--         health.ok('Logger is available')
--     else
--         health.error('Logger not found')
--     end

--     -- Check cache system
--     local cache = require('plugman.core.cache')
--     if cache then
--         health.ok('Cache system is available')
--     else
--         health.error('Cache system not found')
--     end

--     -- Check event system
--     local events = require('plugman.core.events')
--     if events then
--         health.ok('Event system is available')
--     else
--         health.error('Event system not found')
--     end
-- end

-- return M
