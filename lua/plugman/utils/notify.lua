local M = {}

local notify_func = vim.notify

---Setup notification system
---@param opts table Notification options
function M.setup(opts)
    opts = opts or {}

    -- Use mini.notify if available
    -- Use nvim-notify if available
    -- Use snacks if available
    -- Use noice if available
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

---Send info notification
---@param message string Message to show
function M.info(message)
    notify_func(message, vim.log.levels.INFO, { title = 'Plugman' })
end

function M.warn(message)
    notify_func(message, vim.log.levels.WARN, { title = 'Plugman' })
end

function M.error(message)
    notify_func(message, vim.log.levels.ERROR, { title = 'Plugman' })
end

function M.success(message)
    notify_func(message, vim.log.levels.INFO, { title = 'Plugman ✓' })
end

return M

