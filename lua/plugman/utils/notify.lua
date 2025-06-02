local M = {}

local notify_func = vim.notify

---Setup notification system
---@param opts table Notification options
function M.setup(opts)
    opts = opts or {}

    -- Use nvim-notify if available
    -- Use snacks if available
    -- Use noice if available
    -- Use mini.notify if available
    local has_notify, nvim_notify = pcall(require, 'notify')
    local has_snacks, snacks_notification = pcall(require, 'snacks.notification')
    local has_noice, noice = pcall(require, 'noice')
    local has_mini_notify, mini_notify = pcall(require, 'mini.notify')

    if has_notify and opts.use_nvim_notify ~= false then
        notify_func = nvim_notify
    end
    if has_snacks and opts.use_snacks_notification ~= false then
        notify_func = snacks_notification
    end
    if has_noice and opts.use_noice ~= false then
        notify_func = noice
    end
    if has_mini_notify and opts.use_mini_notify ~= false then
        notify_func = mini_notify
    end
end

---Send info notification
---@param message string Message to show
function M.info(message)
    notify_func('[Plugman] ' .. message, vim.log.levels.INFO)
end

---Send warning notification
---@param message string Message to show
function M.warn(message)
    notify_func('[Plugman] ' .. message, vim.log.levels.WARN)
end

---Send error notification
---@param message string Message to show
function M.error(message)
    notify_func('[Plugman] ' .. message, vim.log.levels.ERROR)
end

return M
