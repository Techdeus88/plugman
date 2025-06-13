local M = {}

local config = {
    enabled = true,
    timeout = 3000,
    level = vim.log.levels.INFO,
}

local notify_func = vim.notify

---Setup notifications
---@param opts table Options
function M.setup(opts)
    config = vim.tbl_extend('force', config, opts or {})

    local has_mini_notify, mini_notify = pcall(require, 'mini.notify')
    local has_notify, nvim_notify = pcall(require, 'notify')
    local has_snacks, snacks_notification = pcall(require, 'snacks.notification')
    local has_noice, noice = pcall(require, 'noice')

    if has_mini_notify and opts.use_mini_notify ~= false then
        notify_func = mini_notify
        -- Setup mini.notify with custom options
        mini_notify.setup({
            content = {
                format = function(notification)
                    local title = notification.title or 'Plugman'
                    local message = notification.message
                    return string.format('%s: %s', title, message)
                end,
            },
            window = {
                config = {
                    border = 'rounded',
                    timeout = opts.timeout or 3000,
                },
            },
        })
    elseif has_notify and opts.use_nvim_notify ~= false then
        notify_func = nvim_notify
    elseif has_snacks and opts.use_snacks_notification ~= false then
        notify_func = snacks_notification
    elseif has_noice and opts.use_noice ~= false then
        notify_func = noice
    end
end

---Send notification
---@param message string Message
---@param level number Log level
---@param opts table|nil Options
local function notify(message, level, opts)
    if not config.enabled then
        return
    end

    opts = opts or {}
    opts.timeout = opts.timeout or config.timeout

    if notify_func then
        notify_func(message, level, opts)
    else
        print(message)
    end
end
---Info notification
---@param message string Message
---@param opts table|nil Options
function M.info(message, opts)
    opts = vim.tbl_extend("force", { title = "Plugman" }, opts)
    notify(message, vim.log.levels.INFO, opts)
end
---Warn notification
---@param message string Message
---@param opts table|nil Options
function M.warn(message, opts)
    opts = vim.tbl_extend("force", { title = "Plugman" }, opts)
    notify(message, vim.log.levels.WARN, opts)
end
---Error notification
---@param message string Message
---@param opts table|nil Options
function M.error(message, opts)
    opts = vim.tbl_extend("force", { title = "Plugman" }, opts)
    notify(message, vim.log.levels.ERROR, opts)
end
---Success notification
---@param message string Message
---@param opts table|nil Options
function M.success(message, opts)
    opts = vim.tbl_extend("force", { title = 'Plugman ✓' }, opts)
    notify(message, vim.log.levels.INFO, opts)
end

return M