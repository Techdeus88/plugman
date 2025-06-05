local M = {}

---Check Plugman health
function M.check()
    local health = vim.health or require('health')
    print(vim.inspect(health))

    health.report_start('Plugman Health Check')

    -- Check MiniDeps
    local has_minideps, _ = pcall(require, 'mini.deps')
    if has_minideps then
        health.report_ok('MiniDeps is available')
    else
        health.report_error('MiniDeps not found', 'Please install mini.deps')
    end

    -- Check cache directory
    local cache_dir = vim.fn.stdpath('cache')
    if vim.fn.isdirectory(cache_dir) == 1 then
        health.report_ok('Cache directory exists: ' .. cache_dir)
    else
        health.report_error('Cache directory not found')
    end

    -- Check loaded plugins
    local plugman = require('plugman')
    local loaded_count = #plugman.loaded()
    local total_count = #plugman.list()

    health.report_info(string.format('Plugins: %d loaded, %d total', loaded_count, total_count))

    -- Check for issues
    local lazy_count = #plugman.lazy()
    if lazy_count > 0 then
        health.report_info(string.format('%d plugins are lazy-loaded', lazy_count))
    end
end

return M
