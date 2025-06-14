local Logger = require('plugman.utils.logger')

---@class PlugmanEvents
local Events = {}
Events.__index = Events

-- Event groups for better organization
local EVENT_GROUPS = {
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
    }
}

-- Create a set of all known events for quick lookup
local KNOWN_EVENTS = {}
for _, events in pairs(EVENT_GROUPS) do
    for _, event in ipairs(events) do
        KNOWN_EVENTS[event] = true
    end
end

---Create new events system
---@param loader PlugmanLoader
---@return PlugmanEvents
function Events.new(loader)
    ---@class PlugmanEvents
    local self = setmetatable({}, Events)

    self.loader = loader
    self.event_handlers = {}
    self.command_handlers = {}
    self.filetype_handlers = {}
    self.key_handlers = {}
    self.event_history = {}
    self.debug_mode = false
    self.ungrouped_handlers = {}

    self:setup_autocmds()

    return self
end

---Setup autocmds for event handling
function Events:setup_autocmds()
    local group = vim.api.nvim_create_augroup('PlugmanEvents', { clear = true })

    -- Register events by group
    for group_name, events in pairs(EVENT_GROUPS) do
        local group = vim.api.nvim_create_augroup('Plugman' .. group_name, { clear = true })
        if group_name == "custom" then
            for _, event in ipairs(events) do
                vim.api.nvim_create_autocmd("User", {
                    pattern = event,
                    group = group,
                    callback = function(args)
                        self:handle_event(event, args)
                    end,
                })
            end
        else
            for _, event in ipairs(events) do
                vim.api.nvim_create_autocmd(event, {
                    group = group,
                    callback = function(args)
                        self:handle_event(event, args)
                    end,
                })
            end
        end
    end

    -- Handle ungrouped events
    vim.api.nvim_create_autocmd("User", {
        group = group,
        callback = function(args)
            local event = args.event
            if not KNOWN_EVENTS[event] then
                self:handle_event(event, args)
            end
        end,
    })
end

---Register event handler
---@param events string|table Event name(s)
---@param callback function Callback function
---@param opts table|nil Options
function Events:on_event(events, callback, opts)
    opts = opts or {}
    local event_list = type(events) == 'table' and events or { events }

    for _, event in ipairs(event_list) do
        if not KNOWN_EVENTS[event] then
            -- Handle ungrouped events
            if not self.ungrouped_handlers[event] then
                self.ungrouped_handlers[event] = {}
            end
            table.insert(self.ungrouped_handlers[event], {
                callback = callback,
                priority = opts.priority or 0,
                group = opts.group,
                debug = opts.debug
            })
        else
            -- Handle known events
            if not self.event_handlers[event] then
                self.event_handlers[event] = {}
            end
            table.insert(self.event_handlers[event], {
                callback = callback,
                priority = opts.priority or 0,
                group = opts.group,
                debug = opts.debug
            })
            -- Sort handlers by priority (higher first)
            table.sort(self.event_handlers[event], function(a, b)
                return a.priority > b.priority
            end)
        end
    end
end

---Register command handler
---@param commands string|table Command name(s)
---@param callback function Callback function
---@param opts table|nil Options
function Events:on_command(commands, callback, opts)
    opts = opts or {}
    local cmd_list = type(commands) == 'table' and commands or { commands }

    for _, cmd in ipairs(cmd_list) do
        self.command_handlers[cmd] = {
            callback = callback,
            priority = opts.priority or 0,
            group = opts.group,
            debug = opts.debug
        }
    end
end

---Register filetype handler
---@param filetypes string|table Filetype(s)
---@param callback function Callback function
---@param opts table|nil Options
function Events:on_filetype(filetypes, callback, opts)
    opts = opts or {}
    local ft_list = type(filetypes) == 'table' and filetypes or { filetypes }

    for _, ft in ipairs(ft_list) do
        if not self.filetype_handlers[ft] then
            self.filetype_handlers[ft] = {}
        end
        table.insert(self.filetype_handlers[ft], {
            callback = callback,
            priority = opts.priority or 0,
            group = opts.group,
            debug = opts.debug
        })
        -- Sort handlers by priority (higher first)
        table.sort(self.filetype_handlers[ft], function(a, b)
            return a.priority > b.priority
        end)
    end
end

---Register key handler
---@param keys table Key specifications
---@param callback function Callback function
---@param opts table|nil Options
function Events:on_keys(keys, callback, opts)
    opts = opts or {}
    -- Ensure keys is a table
    if type(keys) ~= 'table' then
        Logger.error("on_keys: keys parameter must be a table, got " .. type(keys))
        return
    end
    for _, key in ipairs(keys) do
        local mode = key.mode or 'n'
        if type(mode) == "table" then
            mode = table.concat(mode, '')
        end
        local lhs = key.lhs or key[1]
        if lhs then
            local key_id = mode .. ':' .. lhs
            self.key_handlers[key_id] = {
                callback = callback,
                priority = opts.priority or 0,
                group = opts.group,
                debug = opts.debug
            }

            -- Create lazy keymap
            vim.keymap.set(mode, lhs, function()
                -- Execute callback first
                callback()

                -- Then execute the original mapping
                vim.schedule(function()
                    local rhs = key.rhs or key[2]
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
    -- Record event in history
    table.insert(self.event_history, {
        event = event,
        args = args,
        time = os.time()
    })
    -- Keep only last 100 events
    if #self.event_history > 100 then
        table.remove(self.event_history, 1)
    end

    -- Handle known events
    local handlers = self.event_handlers[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            -- Skip if handler is in debug mode and debug mode is off
            if handler.debug and not self.debug_mode then
                goto continue
            end

            local ok, err = pcall(handler.callback, args)
            if not ok then
                Logger.error("Event handler failed for " .. event .. ": " .. tostring(err))
            end

            ::continue::
        end
    end

    -- Handle ungrouped events
    local ungrouped_handlers = self.ungrouped_handlers[event]
    if ungrouped_handlers then
        for _, handler in ipairs(ungrouped_handlers) do
            -- Skip if handler is in debug mode and debug mode is off
            if handler.debug and not self.debug_mode then
                goto continue
            end

            local ok, err = pcall(handler.callback, args)
            if not ok then
                Logger.error("Ungrouped event handler failed for " .. event .. ": " .. tostring(err))
            end

            ::continue::
        end
    end
end

---Handle filetype
---@param filetype string Filetype
function Events:handle_filetype(filetype)
    local handlers = self.filetype_handlers[filetype]
    if handlers then
        for _, handler in ipairs(handlers) do
            -- Skip if handler is in debug mode and debug mode is off
            if handler.debug and not self.debug_mode then
                goto continue
            end

            local ok, err = pcall(handler.callback, filetype)
            if not ok then
                Logger.error("Filetype handler failed for " .. filetype .. ": " .. tostring(err))
            end

            ::continue::
        end
    end
end

---Enable/disable debug mode
---@param enabled boolean Whether debug mode should be enabled
function Events:set_debug_mode(enabled)
    self.debug_mode = enabled
end

---Get event history
---@return table Event history
function Events:get_event_history()
    return self.event_history
end

---Clear event history
function Events:clear_event_history()
    self.event_history = {}
end

return Events
