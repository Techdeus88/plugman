local M = {}

local logger = require('plugman.utils.logger')
local notify = require('plugman.utils.notify')

-- Message categories and their prefixes
local CATEGORIES = {
    PLUGMAN = 'Plugman',
    MINIDEPS = 'MiniDeps',
    MASON = 'Mason',
    TREESITTER = 'Treesitter',
    PLUGIN = 'Plugin'
}

-- Message types and their icons
local MESSAGE_TYPES = {
    INFO = { icon = 'ℹ', level = vim.log.levels.INFO },
    SUCCESS = { icon = '✓', level = vim.log.levels.INFO },
    WARN = { icon = '⚠', level = vim.log.levels.WARN },
    ERROR = { icon = '✖', level = vim.log.levels.ERROR }
}

-- Default configuration
M.config = {
    show_notifications = true,
    show_logs = true,
    categories = {
        [CATEGORIES.PLUGMAN] = true,
        [CATEGORIES.MINIDEPS] = true,
        [CATEGORIES.MASON] = true,
        [CATEGORIES.TREESITTER] = true,
        [CATEGORIES.PLUGIN] = true
    }
}

-- Initialize message handler
function M.init(config)
    M.config = vim.tbl_extend('force', M.config, config or {})
end

-- Format message with category and type
local function format_message(category, message_type, message)
    local type_info = MESSAGE_TYPES[message_type]
    if not type_info then return message end

    local prefix = string.format('[%s %s]', type_info.icon, category)
    return string.format('%s %s', prefix, message)
end

-- Handle message from any source
function M.handle(category, message_type, message, opts)
    opts = opts or {}
    local should_notify = opts.notify ~= false and M.config.show_notifications
    local should_log = opts.log ~= false and M.config.show_logs

    -- Check if category is enabled
    if not M.config.categories[category] then return end

    -- Format the message
    local formatted_message = format_message(category, message_type, message)

    -- Log if enabled
    if should_log then
        -- Convert message type to uppercase for logger
        local log_method = message_type:upper()
        if logger[log_method] then
            logger[log_method](formatted_message)
        end
    end

    -- Notify if enabled
    if should_notify then
        -- Convert message type to lowercase for notify
        local notify_method = message_type:lower()
        if notify[notify_method] then
            notify[notify_method](formatted_message)
        end
    end
end

-- Convenience functions for different categories
function M.plugman(message_type, message, opts)
    M.handle(CATEGORIES.PLUGMAN, message_type, message, opts)
end

function M.minideps(message_type, message, opts)
    M.handle(CATEGORIES.MINIDEPS, message_type, message, opts)
end

function M.mason(message_type, message, opts)
    M.handle(CATEGORIES.MASON, message_type, message, opts)
end

function M.treesitter(message_type, message, opts)
    M.handle(CATEGORIES.TREESITTER, message_type, message, opts)
end

function M.plugin(plugin_name, message_type, message, opts)
    local category = string.format('%s: %s', CATEGORIES.PLUGIN, plugin_name)
    M.handle(category, message_type, message, opts)
end

-- Export categories and message types for external use
M.CATEGORIES = CATEGORIES
M.MESSAGE_TYPES = MESSAGE_TYPES

return M 