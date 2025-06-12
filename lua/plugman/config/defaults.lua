return {
    -- Cache configuration
    cache = {
        enabled = true,
        auto_save = true
    },

    -- Logging configuration
    logging = {
        level = 'INFO', -- DEBUG, INFO, WARN, ERROR
        file = true,
        console = false,
    },

    -- UI configuration
    ui = {
        border = 'rounded',
        size = { width = 0.8, height = 0.8 },
        transparency = 0,
    },

    -- Performance configuration
    performance = {
        lazy_timer = 2000, -- ms delay for lazy plugins without triggers
    },

    -- Notification configuration
    notify = {
        use_snacks_notify = false,
        use_mini_notify = true,
        use_noice = false,
        use_nvim_notify = false,
        timeout = 3000,
        stages = 'fade_in_slide_out',
        background_colour = '#000000',
        icons = {
            ERROR = '✖',
            WARN = '⚠',
            INFO = 'ℹ',
            SUCCESS = '✓'
        },
        -- Control whether to show notifications during plugin loading
        show_loading_notifications = false
    },

    -- Message handler configuration
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

    -- Plugin and module paths
    paths = {
        plugins_dir = "plugins",
        -- Path to modules directory (for module-based configuration)
        plugins_path = vim.fn.stdpath('config') .. '/lua'
    }
}
