local logger = require('plugman.utils.logger')

---@class EventManager
---@field handlers table<string, table> Event handlers
---@field emitted table<string, any> Emitted events
---@field callbacks table<string, function[]> Event callbacks
local EventManager = {
    handlers = {},
    emitted = {},
    callbacks = {},
}



---Register an event handler
---@param event_name string Name of the event
---@param event_data table Event data containing handler and metadata
---@return boolean success Whether registration was successful
function EventManager:register_handler(event_name, event_data)
    if not self:validate_event_data(event_data) then
        logger.error(string.format("Invalid event data for %s", event_name))
        return false
    end

    self.handlers[event_name] = self.handlers[event_name] or {}
    table.insert(self.handlers[event_name], {
        event_data = event_data,
        module_id = event_data.module_id,
    })

    -- Trigger handler immediately if event was already emitted
    if self.emitted[event_name] then
        event_data.handler(self.emitted[event_name])
    end

    return true
end

---Validate event data structure
---@param event_data table Event data to validate
---@return boolean valid Whether the event data is valid
function EventManager:validate_event_data(event_data)
    return event_data
        and event_data.handler
        and type(event_data.handler) == "function"
end

---Get all handlers for an event
---@param event string Event name
---@return table|nil handlers Event handlers
function EventManager:get_handlers(event)
    return self.handlers[event]
end

---Emit an event and trigger its handlers
---@param event_name string Name of the event
---@param data any Event data
---@param is_urgent boolean Whether this is an urgent event
function EventManager:emit_event(event_name, data, is_urgent)
    self.emitted[event_name] = data

    local handlers = self.handlers[event_name]
    if not handlers then return end

    for _, handler_entry in ipairs(handlers) do
        if handler_entry.event_data and handler_entry.event_data.handler then
            handler_entry.event_data.handler(data)
        end
    end
end

---Register a callback for an event
---@param event string Event name
---@param callback function Callback function
function EventManager:on_event(event, callback)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], callback)
    logger.debug(string.format('Registered event callback for: %s', event))
end

---Register a callback for a filetype
---@param filetype string Filetype
---@param callback function Callback function
function EventManager:on_filetype(filetype, callback)
    self.callbacks[filetype] = self.callbacks[filetype] or {}
    table.insert(self.callbacks[filetype], callback)
    logger.debug(string.format('Registered filetype callback for: %s', filetype))
end

---Register a command callback
---@param command string Command name
---@param callback function Callback function
function EventManager:on_command(command, callback)
    self.callbacks[command] = callback

    vim.api.nvim_create_user_command(command, function(args)
        callback(args)
    end, {
        nargs = '*',
        desc = string.format('Lazy-loaded command: %s', command)
    })

    logger.debug(string.format('Registered command callback for: %s', command))
end

---Register a key callback
---@param keys table|string Key mappings
---@param callback function Callback function
function EventManager:on_keys(keys, callback)
    local key_list = type(keys) == 'table' and keys or { keys }

    for _, key in ipairs(key_list) do
        local lhs, mode, opts = self:parse_key_spec(key)
        if lhs then
            self[lhs] = callback
            self:setup_lazy_keymap(lhs, mode, opts, callback)
        end
    end
end

---Parse a key specification
---@param key string|table Key specification
---@return string|nil lhs Left-hand side of the mapping
---@return string mode Mode for the mapping
---@return table opts Mapping options
function EventManager:parse_key_spec(key)
    if type(key) == 'string' then
        return key, 'n', {}
    elseif type(key) == 'table' then
        return key[1] or key.lhs, key.mode or 'n', key.opts or {}
    end
    return nil
end

---Setup a lazy keymap
---@param lhs string Left-hand side of the mapping
---@param mode string Mode for the mapping
---@param opts table Mapping options
---@param callback function Callback function
function EventManager:setup_lazy_keymap(lhs, mode, opts, callback)
    vim.keymap.set(mode, lhs, function()
        callback()
        vim.keymap.del(mode, lhs)
    end, opts)
    logger.debug(string.format('Registered key callback for: %s', lhs))
end

---Trigger event callbacks
---@param event string Event name
function EventManager:_trigger_event(event)
    local callbacks = self.callbacks[event]
    if not callbacks then return end

    for _, callback in ipairs(callbacks) do
        pcall(callback)
    end
    self.callbacks[event] = nil
end

---Trigger filetype callbacks
---@param filetype string Filetype
function EventManager:_trigger_filetype(filetype)
    local callbacks = self.callbacks[filetype]
    if not callbacks then return end

    for _, callback in ipairs(callbacks) do
        pcall(callback)
    end
    self.callbacks[filetype] = nil
end

---Setup the event system
function EventManager.setup()
    local function safe_trigger_event(event, args)
        local handlers = EventManager:get_handlers(event)
        if not handlers then return end

        for _, entry in ipairs(handlers) do
            if not entry.event_data.module_id then goto continue end

            local module = require("core").get_plugin(entry.event_data.plugin_id)
            if not module or module.loaded then goto continue end

            local ok, err = pcall(entry.event_data.handler, args)
            if not ok then
                logger.error(string.format('Handler failed for %s on event %s: %s',
                    module.name, event, err))
            end
            ::continue::
        end
    end

    -- Event groups for better organization
    local event_groups = {
        buffer = {
            'BufAdd', 'BufDelete', 'BufEnter', 'BufLeave', 'BufNew',
            'BufNewFile', 'BufRead', 'BufReadPost', 'BufReadPre',
            'BufUnload', 'BufWinEnter', 'BufWinLeave', 'BufWrite',
            'BufWritePre', 'BufWritePost',
        },
        file = {
            'FileType', 'FileReadCmd', 'FileWriteCmd', 'FileAppendCmd',
            'FileAppendPost', 'FileAppendPre', 'FileChangedShell',
            'FileChangedShellPost', 'FileReadPost', 'FileReadPre',
            'FileWritePost', 'FileWritePre',
        },
        window = {
            'WinClosed', 'WinEnter', 'WinLeave', 'WinNew', 'WinScrolled',
        },
        terminal = {
            'TermOpen', 'TermClose', 'TermEnter', 'TermLeave', 'TermChanged',
        },
        tab = {
            'TabEnter', 'TabLeave', 'TabNew', 'TabNewEntered',
        },
        text = {
            'TextChanged', 'TextChangedI', 'TextChangedP', 'TextYankPost',
        },
        insert = {
            'InsertChange', 'InsertCharPre', 'InsertEnter', 'InsertLeave',
        },
        vim = {
            'VimEnter', 'VimLeave', 'VimLeavePre', 'VimResized',
        },
        custom = {
            'BaseDefered', 'BaseFile', 'BaseGitFile', 'TechdeusStart',
            'TechdeusReady', 'DashboardUpdate', 'PluginLoad', 'PluginUnload'
        },
    }

    -- Register events by group
    for group_name, events in pairs(event_groups) do
        local group = vim.api.nvim_create_augroup('Store' .. group_name, { clear = true })
        for _, event in ipairs(events) do
            if group_name == 'custom' then
                EventManager:register_handler(event, {
                    handler = function(args)
                        safe_trigger_event(event, args)
                    end
                })

                vim.api.nvim_create_autocmd('User', {
                    group = group,
                    pattern = event,
                    callback = function(args)
                        safe_trigger_event(event, args)
                    end,
                })
            else
                vim.api.nvim_create_autocmd(event, {
                    group = group,
                    pattern = event == 'FileType' and '*' or nil,
                    callback = function(args)
                        safe_trigger_event(event, args)
                    end,
                })
            end
        end
    end
end

return EventManager

--End-of-file--
-- Trigger an event and execute its handlers
-- function module_manager:trigger_event(event, args)
--   local event_callbacks = self:get_handlers(event)
--   if event_callbacks then
--     for _, entry in ipairs(event_callbacks) do
--       local module = self.modules[entry.module_id]
--       if module and module.added then
--         if event == 'FileType' and args then
--           local buf_ft = vim.api.nvim_buf_get_option(args.buf, 'filetype')
--           if buf_ft == entry.event_data.ft then
--             entry.event_data.handler(args)
--           end
--         else
--           entry.event_data.handler(args)
--         end
--       end
--     end
--   end
-- end
--End-of-file--
