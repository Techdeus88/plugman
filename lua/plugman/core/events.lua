local Logger = require('plugman.utils.logger')

---@class PlugmanEvents
local Events = {}
Events.__index = Events

---Create new events system
---@param loader PlugmanLoader
---@return PlugmanEvents
function Events.new(loader)
    local self = setmetatable({}, Events)

    self.loader = loader
    self.event_handlers = {}
    self.command_handlers = {}
    self.filetype_handlers = {}
    self.key_handlers = {}

    self:setup_autocmds()

    return self
end

---Setup autocmds for event handling
function Events:setup_autocmds()
    local group = vim.api.nvim_create_augroup('PlugmanEvents', { clear = true })

    -- Generic event handler
    vim.api.nvim_create_autocmd('*', {
        group = group,
        callback = function(args)
            self:handle_event(args.event, args)
        end,
    })

    -- Filetype specific
    vim.api.nvim_create_autocmd('FileType', {
        group = group,
        callback = function(args)
            self:handle_filetype(args.match)
        end,
    })
end

---Register event handler
---@param events string|table Event name(s)
---@param callback function Callback function
function Events:on_event(events, callback)
    local event_list = type(events) == 'table' and events or { events }

    for _, event in ipairs(event_list) do
        if not self.event_handlers[event] then
            self.event_handlers[event] = {}
        end
        table.insert(self.event_handlers[event], callback)
    end
end

---Register command handler
---@param commands string|table Command name(s)
---@param callback function Callback function
function Events:on_command(commands, callback)
    local cmd_list = type(commands) == 'table' and commands or { commands }

    for _, cmd in ipairs(cmd_list) do
        self.command_handlers[cmd] = callback
    end
end

---Register filetype handler
---@param filetypes string|table Filetype(s)
---@param callback function Callback function
function Events:on_filetype(filetypes, callback)
    local ft_list = type(filetypes) == 'table' and filetypes or { filetypes }

    for _, ft in ipairs(ft_list) do
        if not self.filetype_handlers[ft] then
            self.filetype_handlers[ft] = {}
        end
        table.insert(self.filetype_handlers[ft], callback)
    end
end

---Register key handler
---@param keys table Key specifications
---@param callback function Callback function
function Events:on_keys(keys, callback)
    for _, key in ipairs(keys) do
        local mode = key.mode or key[1] or 'n'
        local lhs = key.lhs or key[2]

        if lhs then
            local key_id = mode .. ':' .. lhs
            self.key_handlers[key_id] = callback

            -- Create lazy keymap
            vim.keymap.set(mode, lhs, function()
                -- Execute callback first
                callback()

                -- Then execute the original mapping
                vim.schedule(function()
                    local rhs = key.rhs or key[3]
                    if rhs then
                        if type(rhs) == 'function' then
                            rhs()
                        else
                            vim.cmd(rhs)
                        end
                    end
                end)
            end, { desc = key.desc })
        end
    end
end

---Handle event
---@param event string Event name
---@param args table Event arguments
function Events:handle_event(event, args)
    local handlers = self.event_handlers[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            local ok, err = pcall(handler, args)
            if not ok then
                Logger.error("Event handler failed for " .. event .. ": " .. tostring(err))
            end
        end
    end
end

---Handle filetype
---@param filetype string Filetype
function Events:handle_filetype(filetype)
    local handlers = self.filetype_handlers[filetype]
    if handlers then
        for _, handler in ipairs(handlers) do
            local ok, err = pcall(handler, filetype)
            if not ok then
                Logger.error("Filetype handler failed for " .. filetype .. ": " .. tostring(err))
            end
        end
    end
end

return Events

-- local logger = require('plugman.utils.logger')

-- ---@class EventManager
-- ---@field handlers table<string, table> Event handlers
-- ---@field emitted table<string, any> Emitted events
-- ---@field callbacks table<string, function[]> Event callbacks
-- local EventManager = {
--     handlers = {},
--     emitted = {},
--     callbacks = {},
-- }

-- ---Register an event handler
-- ---@param event_name string Name of the event
-- ---@param event_data table Event data containing handler and metadata
-- ---@return boolean success Whether registration was successful
-- function EventManager:register_handler(event_name, event_data)
--     if not self:validate_event_data(event_data) then
--         logger.error(string.format("Invalid event data for %s", event_name))
--         return false
--     end

--     self.handlers[event_name] = self.handlers[event_name] or {}
--     table.insert(self.handlers[event_name], {
--         event_data = event_data,
--         module_id = event_data.module_id,
--     })

--     -- Trigger handler immediately if event was already emitted
--     if self.emitted[event_name] then
--         event_data.handler(self.emitted[event_name])
--     end

--     return true
-- end

-- ---Validate event data structure
-- ---@param event_data table Event data to validate
-- ---@return boolean valid Whether the event data is valid
-- function EventManager:validate_event_data(event_data)
--     return event_data
--         and event_data.handler
--         and type(event_data.handler) == "function"
-- end

-- ---Get all handlers for an event
-- ---@param event string Event name
-- ---@return table|nil handlers Event handlers
-- function EventManager:get_handlers(event)
--     return self.handlers[event]
-- end

-- ---Emit an event and trigger its handlers
-- ---@param event_name string Name of the event
-- ---@param data any Event data
-- ---@param is_urgent boolean Whether this is an urgent event
-- function EventManager:emit_event(event_name, data, is_urgent)
--     self.emitted[event_name] = data

--     local handlers = self.handlers[event_name]
--     if not handlers then return end

--     for _, handler_entry in ipairs(handlers) do
--         if handler_entry.event_data and handler_entry.event_data.handler then
--             handler_entry.event_data.handler(data)
--         end
--     end
-- end

-- ---Register a callback for an event
-- ---@param event string Event name
-- ---@param callback function Callback function
-- function EventManager:on_event(event, callback)
--     self.callbacks[event] = self.callbacks[event] or {}
--     table.insert(self.callbacks[event], callback)
--     logger.debug(string.format('Registered event callback for: %s', event))
-- end

-- ---Register a callback for a filetype
-- ---@param filetype string Filetype
-- ---@param callback function Callback function
-- function EventManager:on_filetype(filetype, callback)
--     self.callbacks[filetype] = self.callbacks[filetype] or {}
--     table.insert(self.callbacks[filetype], callback)
--     logger.debug(string.format('Registered filetype callback for: %s', filetype))
-- end

-- ---Register a command callback
-- ---@param command string Command name
-- ---@param callback function Callback function
-- function EventManager:on_command(command, callback)
--     self.callbacks[command] = callback

--     vim.api.nvim_create_user_command(command, function(args)
--         callback(args)
--     end, {
--         nargs = '*',
--         desc = string.format('Lazy-loaded command: %s', command)
--     })

--     logger.debug(string.format('Registered command callback for: %s', command))
-- end

-- ---Register a key callback
-- ---@param keys table|string Key mappings
-- ---@param callback function Callback function
-- function EventManager:on_keys(keys, callback)
--     local key_list = type(keys) == 'table' and keys or { keys }

--     for _, key in ipairs(key_list) do
--         local lhs, mode, opts = self:parse_key_spec(key)
--         if lhs then
--             self[lhs] = callback
--             self:setup_lazy_keymap(lhs, mode, opts, callback)
--         end
--     end
-- end

-- ---Parse a key specification
-- ---@param key string|table Key specification
-- ---@return string|nil lhs Left-hand side of the mapping
-- ---@return string mode Mode for the mapping
-- ---@return table opts Mapping options
-- function EventManager:parse_key_spec(key)
--     if type(key) == 'string' then
--         return key, 'n', {}
--     elseif type(key) == 'table' then
--         return key[1] or key.lhs, key.mode or 'n', key.opts or {}
--     end
--     return nil
-- end

-- ---Setup a lazy keymap
-- ---@param lhs string Left-hand side of the mapping
-- ---@param mode string Mode for the mapping
-- ---@param opts table Mapping options
-- ---@param callback function Callback function
-- function EventManager:setup_lazy_keymap(lhs, mode, opts, callback)
--     vim.keymap.set(mode, lhs, function()
--         callback()
--         vim.keymap.del(mode, lhs)
--     end, opts)
--     logger.debug(string.format('Registered key callback for: %s', lhs))
-- end

-- ---Trigger event callbacks
-- ---@param event string Event name
-- function EventManager:_trigger_event(event)
--     local callbacks = self.callbacks[event]
--     if not callbacks then return end

--     for _, callback in ipairs(callbacks) do
--         pcall(callback)
--     end
--     self.callbacks[event] = nil
-- end

-- ---Trigger filetype callbacks
-- ---@param filetype string Filetype
-- function EventManager:_trigger_filetype(filetype)
--     local callbacks = self.callbacks[filetype]
--     if not callbacks then return end

--     for _, callback in ipairs(callbacks) do
--         pcall(callback)
--     end
--     self.callbacks[filetype] = nil
-- end

-- ---Setup the event system
-- function EventManager.setup()
--     local function safe_trigger_event(event, args)
--         local handlers = EventManager:get_handlers(event)
--         if not handlers then return end

--         for _, entry in ipairs(handlers) do
--             if not entry.event_data.module_id then goto continue end

--             local module = require("core").get_plugin(entry.event_data.plugin_id)
--             if not module or module.loaded then goto continue end

--             local ok, err = pcall(entry.event_data.handler, args)
--             if not ok then
--                 logger.error(string.format('Handler failed for %s on event %s: %s',
--                     module.name, event, err))
--             end
--             ::continue::
--         end
--     end

--     -- Event groups for better organization
--     local event_groups = {
--         buffer = {
--             'BufAdd', 'BufDelete', 'BufEnter', 'BufLeave', 'BufNew',
--             'BufNewFile', 'BufRead', 'BufReadPost', 'BufReadPre',
--             'BufUnload', 'BufWinEnter', 'BufWinLeave', 'BufWrite',
--             'BufWritePre', 'BufWritePost',
--         },
--         file = {
--             'FileType', 'FileReadCmd', 'FileWriteCmd', 'FileAppendCmd',
--             'FileAppendPost', 'FileAppendPre', 'FileChangedShell',
--             'FileChangedShellPost', 'FileReadPost', 'FileReadPre',
--             'FileWritePost', 'FileWritePre',
--         },
--         window = {
--             'WinClosed', 'WinEnter', 'WinLeave', 'WinNew', 'WinScrolled',
--         },
--         terminal = {
--             'TermOpen', 'TermClose', 'TermEnter', 'TermLeave', 'TermChanged',
--         },
--         tab = {
--             'TabEnter', 'TabLeave', 'TabNew', 'TabNewEntered',
--         },
--         text = {
--             'TextChanged', 'TextChangedI', 'TextChangedP', 'TextYankPost',
--         },
--         insert = {
--             'InsertChange', 'InsertCharPre', 'InsertEnter', 'InsertLeave',
--         },
--         vim = {
--             'VimEnter', 'VimLeave', 'VimLeavePre', 'VimResized',
--         },
--         custom = {
--             'BaseDefered', 'BaseFile', 'BaseGitFile', 'TechdeusStart',
--             'TechdeusReady', 'DashboardUpdate', 'PluginLoad', 'PluginUnload'
--         },
--     }

--     -- Register events by group
--     for group_name, events in pairs(event_groups) do
--         local group = vim.api.nvim_create_augroup('Store' .. group_name, { clear = true })
--         for _, event in ipairs(events) do
--             if group_name == 'custom' then
--                 EventManager:register_handler(event, {
--                     handler = function(args)
--                         safe_trigger_event(event, args)
--                     end
--                 })

--                 vim.api.nvim_create_autocmd('User', {
--                     group = group,
--                     pattern = event,
--                     callback = function(args)
--                         safe_trigger_event(event, args)
--                     end,
--                 })
--             else
--                 vim.api.nvim_create_autocmd(event, {
--                     group = group,
--                     pattern = event == 'FileType' and '*' or nil,
--                     callback = function(args)
--                         safe_trigger_event(event, args)
--                     end,
--                 })
--             end
--         end
--     end
-- end

-- return EventManager

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
