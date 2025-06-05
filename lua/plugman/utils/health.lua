local M = {}


---Check Plugman health
function M.check()
    local health = vim.health or require('health')
    local start = vim.health.start or vim.health.report_start
    local ok = vim.health.ok or vim.health.report_ok
    local warn = vim.health.warn or vim.health.report_warn
    local error = vim.health.error or vim.health.report_error
    local info = vim.health.info or vim.health.report_info

    start('Plugman Health Check')

    -- Check MiniDeps
    local has_minideps, _ = pcall(require, 'mini.deps')
    if has_minideps then
        ok('MiniDeps is available')
    else
        error('MiniDeps not found', 'Please install mini.deps')
    end

    -- Check cache directory
    local cache_dir = vim.fn.stdpath('cache')
    if vim.fn.isdirectory(cache_dir) == 1 then
        ok('Cache directory exists: ' .. cache_dir)
    else
        error('Cache directory not found')
    end

    -- Check loaded plugins
    local plugman = require('plugman')
    local loaded_count = #plugman.loaded()
    local total_count = #plugman.list()

    info(string.format('Plugins: %d loaded, %d total', loaded_count, total_count))

    -- Check for issues
    local lazy_count = #plugman.lazy()
    if lazy_count > 0 then
        info(string.format('%d plugins are lazy-loaded', lazy_count))
    end
end

return M
