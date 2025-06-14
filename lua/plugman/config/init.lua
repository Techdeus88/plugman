local M = {}

---Default configuration
local defaults = {
    -- Paths
    paths = {
        -- Directory for API calls, setup, and loading
        modules_dir = 'modules',
        -- Directories for plugin specifications
        plugins_dir = {
            'plugins',
            'plugins.local' -- For local-only plugins
        },
        -- Installation directory
        install_dir = vim.fn.stdpath('data') .. '/site/pack/deps',
        -- Cache directory
        cache_dir = vim.fn.stdpath('cache') .. '/plugman',
        -- Snapshot directory
        snapshot_dir = vim.fn.stdpath('data') .. '/plugman/snapshots'
    },

    -- UI configuration
    ui = {
        width = 0.8,
        height = 0.8,
        border = 'rounded',
        icons = {
            installed = '●',
            not_installed = '○',
            added = '✓',
            not_added = '✗',
            loaded = '✓',
            not_loaded = '○',
            lazy = '💤',
            not_lazy = ' ',
            priority = '⚡'
        }
    },

    -- Performance settings
    performance = {
        lazy_time = 2000, -- Time to wait before loading lazy plugins
        cache_ttl = 3600, -- Cache TTL in seconds
        max_parallel = 4 -- Maximum number of parallel plugin operations
    },

    -- Logging configuration
    logging = {
        level = 'info',
        file = vim.fn.stdpath('cache') .. '/plugman.log'
    },

    -- Notification settings
    notify = {
        enabled = true,
        timeout = 3000,
        show_loading_notifications = true
    },

    -- Message settings
    messages = {
        show_errors = true,
        show_warnings = true,
        show_info = true
    }
}

---Setup configuration
---@param opts table|nil User configuration
---@return table Configuration
function M.setup(opts)
    opts = opts or {}
    return vim.tbl_deep_extend('force', defaults, opts)
end

return M
