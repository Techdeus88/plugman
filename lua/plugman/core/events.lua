local M = {}

local logger = require('plugman.utils.logger')

local event_callbacks = {}
local command_callbacks = {}
local filetype_callbacks = {}
local key_callbacks = {}

---Setup event system
function M.setup()
    -- Setup autocmds for events
    vim.api.nvim_create_autocmd('*', {
        callback = function(args)
            M._trigger_event(args.event)
        end
    })

    -- Setup filetype detection
    vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
            M._trigger_filetype(args.match)
        end
    })
end

---Register event callback
---@param event string Event name
---@param callback function Callback function
function M.on_event(event, callback)
    event_callbacks[event] = event_callbacks[event] or {}
    table.insert(event_callbacks[event], callback)

    logger.debug(string.format('Registered event callback for: %s', event))
end

---Register filetype callback
---@param filetype string Filetype
---@param callback function Callback function
function M.on_filetype(filetype, callback)
    filetype_callbacks[filetype] = filetype_callbacks[filetype] or {}
    table.insert(filetype_callbacks[filetype], callback)

    logger.debug(string.format('Registered filetype callback for: %s', filetype))
end

---Register command callback
---@param command string Command name
---@param callback function Callback function
function M.on_command(command, callback)
    command_callbacks[command] = callback

    -- Create the command
    vim.api.nvim_create_user_command(command, function(args)
        callback(args)
    end, {
        nargs = '*',
        desc = string.format('Lazy-loaded command: %s', command)
    })

    logger.debug(string.format('Registered command callback for: %s', command))
end

---Register key callback
---@param keys table|string Key mappings
---@param callback function Callback function
function M.on_keys(keys, callback)
    local key_list = type(keys) == 'table' and keys or { keys }

    for _, key in ipairs(key_list) do
        local lhs, mode, opts

        if type(key) == 'string' then
            lhs = key
            mode = 'n'
            opts = {}
        elseif type(key) == 'table' then
            lhs = key[1] or key.lhs
            mode = key.mode or 'n'
            opts = key.opts or {}
        end

        if lhs then
            key_callbacks[lhs] = callback

            -- Create lazy keymap
            vim.keymap.set(mode, lhs, function()
                callback()
                -- Remove this lazy keymap after triggering
                vim.keymap.del(mode, lhs)
            end, opts)

            logger.debug(string.format('Registered key callback for: %s', lhs))
        end
    end
end

---Trigger event callbacks
---@param event string Event name
function M._trigger_event(event)
    if event_callbacks[event] then
        for _, callback in ipairs(event_callbacks[event]) do
            pcall(callback)
        end
        -- Clear callbacks after triggering
        event_callbacks[event] = nil
    end
end

---Trigger filetype callbacks
---@param filetype string Filetype
function M._trigger_filetype(filetype)
    if filetype_callbacks[filetype] then
        for _, callback in ipairs(filetype_callbacks[filetype]) do
            pcall(callback)
        end
        -- Clear callbacks after triggering
        filetype_callbacks[filetype] = nil
    end
end

return M