local M = {}

---Default configuration
local defaults = {
    paths = {
        -- Installation directories
        install_dir = vim.fn.stdpath('data') .. '/plugman',
        snapshot_dir = vim.fn.stdpath('cache') .. '/plugman/snapshots',
        plugins_dir = { 'plugins', 'modules' },
        plugins_path = vim.fn.stdpath('config') .. '/lua'
    },
    -- Behavior
    behavior = {
        silent = false,
        lazy_by_default = true,
        auto_install = true,
        auto_update = false,
    },
    cache = {
        cache_dir = vim.fn.stdpath('cache') .. '/plugman',
        enabled = true,
        auto_save = true
    },
    -- Logging
    logging = {
        level = 'INFO', -- DEBUG, INFO, WARN, ERROR
        file = true,
        console = false,
        log_file = vim.fn.stdpath('cache') .. '/plugman/plugman.log',
    },
    -- Notifications
    notify = {
        enabled = true,
        timeout = 3000,
        level = 'info',
        use_snacks_notify = false,
        use_mini_notify = true,
        use_noice = false,
        use_nvim_notify = false,
        stages = 'fade_in_slide_out',
        background_colour = '#000000',
        icons = {
            ERROR = '✖',
            WARN = '⚠',
            INFO = 'ℹ',
            SUCCESS = '✓'
        },
        -- Show notifications during plugin loading
        show_loading_notifications = false
    },
    -- UI
    ui = {
        border = 'rounded',
        transparency = 0,
        width = 0.8,
        height = 0.8,
        icons = {
            installed = '●',
            not_installed = '○',
            loaded = '✓',
            not_loaded = '✗',
            lazy = '💤',
            not_lazy = '󰑮',
            priority = '⚡',
        },
    },
    -- MiniDeps configuration
    mini_deps = {
        cache = { enabled = true, path = vim.fn.stdpath("cache") .. "/mini-deps", ttl = 86400 },
        job = { n_threads = 4, timeout = 30000, retry = 2 },
        path = {
            package = vim.fn.stdpath("data") .. "/site",
            -- Default file path for a snapshot
            snapshot = vim.fn.stdpath('config') .. '/mini-deps-snap',
            -- Log file
            log = vim.fn.stdpath('log') .. '/mini-deps.log'
        },
        silent = false,
    },
    messages = {
        show_notifications = true,
        show_logs = true,
        categories = {
            plugman = true,
            minideps = true,
            mason = true,
            treesitter = true,
            plugin = true
        },
        -- Control which message types are shown
        types = {
            info = true,
            success = true,
            warn = true,
            error = true
        }
    },
    -- Performance
    performance = {
        cache_ttl = 3600, -- 1 hour
        lazy_time = 2000, -- 2 seconds
        timeout = 30000,  -- 30 seconds
        max_concurrent_installs = 4,
    },
}

---Setup configuration
---@param opts table User configuration
---@return table Final configuration
function M.setup(opts)
    return vim.tbl_deep_extend('force', defaults, opts or {})
end

return M
