---@class Store 
---@class Plugman
---@field public _plugins table<string, PlugmanPlugin>
---@field public _priority_plugins table<string, PlugmanPlugin>
---@field public _lazy_plugins table<string, PlugmanPlugin>
---@field public _failed_plugins table<string, PlugmanPlugin>
---@field public _loaded table<string, boolean>
---@field public start number
---@field public setup_done boolean
---@field public opts table Configuration options
local Store = {}

-- State
Store._plugins = {}
Store._start = 0
Store._priority_plugins = {}
Store._lazy_plugins = {}
Store._failed_plugins = {}
Store._loaded = {}
Store._setup_done = false
Store.opts = nil

-- Setup method
local setup = function()
    -- Make the store global
    _G.Store = Store
end

return { init = setup }
--End-of-file--