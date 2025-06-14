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
            'modules' -- For local-only plugins
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
        max_parallel = 4  -- Maximum number of parallel plugin operations
    },

    -- Logging configuration
    logging = {
        level = 'info',
        file = vim.fn.stdpath('cache') .. '/plugman.log',
        console = false,
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
    },
    minideps = {
        job = {
            -- Number of parallel threads to use. Default: 80% of all available.
            n_threads = nil,

            -- Timeout (in ms) for each job before force quit
            timeout = 30000,
        },

        -- Paths describing where to store data
        path = {
            -- Directory for built-in package.
            -- All plugins are actually stored in 'pack/deps' subdirectory.
            package = vim.fn.stdpath('data') .. '/site',

            -- Default file path for a snapshot
            snapshot = vim.fn.stdpath('config') .. '/mini-deps-snap',

            -- Log file
            --minidoc_replace_start log = vim.fn.stdpath('log') .. '/mini-deps.log'
            log = vim.fn.stdpath('log') .. '/mini-deps.log',
            --minidoc_replace_end
        },

        -- Whether to disable showing non-error feedback
        silent = false,

    }
}

-- Initialize with defaults
M._config = vim.deepcopy(defaults)

-- Copy defaults to top level for direct access
for k, v in pairs(defaults) do
    M[k] = v
end

---Setup configuration
---@param opts table|nil User configuration
---@return table Configuration
function M.setup(opts)
    opts = opts or {}
    M._config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts)
    -- Update top-level keys
    for k, v in pairs(M._config) do
        M[k] = v
    end
    return M._config
end

---Get current configuration
---@return table Configuration
function M.get()
    return M._config
end

setmetatable(M, {
    __index = function(_, k)
        return M._config[k]
    end
})

return M
