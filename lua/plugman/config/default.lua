return {
    -- Logging configuration
    log_level = 'info', -- debug, info, warn, error

    -- Cache configuration
    cache = {
        enabled = true,
        auto_save = true
    },

    -- Notification configuration
    notify = {
        use_snacks_notify = true,
        use_mini_notify = false,
        use_noice = false,
        use_nvim_notify = false,
        timeout = 3000
    },

    -- MiniDeps configuration
    minideps = {
        cache = { enabled = true, path = vim.fn.stdpath("cache") .. "/mini-deps", ttl = 86400 },
        job = { n_threads = 2, timeout = 30000, retry = 2 },
        path = { 
            package = vim.fn.stdpath("data") .. "/site",
            -- Default file path for a snapshot
            snapshot = vim.fn.stdpath('config') .. '/mini-deps-snap',
            -- Log file
            log = vim.fn.stdpath('log') .. '/mini-deps.log' 
        },
        silent = false,
    },

    -- UI configuration
    ui = {
        size = { width = 0.8, height = 0.8 },
        border = 'rounded'
    },

    -- Plugin and module paths
    paths = {
        -- Path to modules directory (for module-based configuration)
        modules_path = vim.fn.stdpath('config') .. '/lua/modules',
        -- Path to plugins directory (for individual plugin configurations)
        plugins_path = vim.fn.stdpath('config') .. '/lua/plugins'
    }
}