--Start-of-file--
local M = {}

local logger = require("plugman.utils.logger")
require("plugman.types.plugin")

---@class PlugmanPlugin
local Plugin = {}
Plugin.__index = Plugin

---@param name string
---@return PlugmanPlugin|nil
function Plugin:get_plugin(name)
    local p = require("plugman")._plugins[name]
    if p ~= nil then
        return p
    end
    return nil
end

---@return PlugmanPlugin|PlugmanRegister|PlugmanLoad|nil A slice of the plugmanplugin, plugmanregister for MiniDeps.add to register, and plugmanload to setup and load
---@param spec any
function Plugin:new(spec)
    local plugin = setmetatable(vim.tbl_deep_extend("force", vim.deepcopy(spec), {
        enabled = spec.enabled or true,
        added = false,
        loaded = false,
        loading = false,
        load_time = nil,
        dependents = {},
    }), self)

    plugin:format_register()
    plugin:format_load()

    plugin:validate()
    return plugin
end

-- Format the "add" structure of a module
function Plugin:format_register()
    local register_module = {}
    register_module.source = self.source
    register_module.depends = self.depends
    register_module.hooks = self.hooks
    register_module.checkout = self.checkout
    register_module.monitor = self.monitor
    self.register = register_module
    setmetatable(self.register, self)
  end
  
  -- Format the "config" structure of a module
  function Plugin:format_load()
    local load_module = {}
    load_module.cmd = self.cmd
    load_module.event = self.event
    load_module.ft = self.ft
    load_module.lazy = self.lazy
    load_module.config = self.config
    load_module.opts = self.opts
    load_module.init = self.init
    load_module.keys = self.keys
    load_module.require = self.require
    self.load = load_module
    setmetatable(self.load, self)
  end

-- Helper functions
function Plugin:validate()
    local plugin = self
    if not plugin.name then
        logger.error("Plugin spec missing required 'name' field")
        return false
    end

    -- Validate source format using utils
    local utils = require("plugman.utils")
    if not plugin.source or not utils.is_valid_github_url(plugin.source) then
        logger.error(string.format("Plugin %s missing required 'source' field", plugin.name))
        return false
    end
    if not plugin.register or not plugin.load then
        logger.error(string.format("Plugin %s missing required register or load fields", plugin.name))
        return false
    end

    return true
end

function Plugin:has_added()
    if not self.added then
        self.added = true
        return true
    end
    logger.warn("Plugin already added")
    return nil
end

function Plugin:has_loaded()
    local end_time = vim.uv.hrtime()
    if not self.loaded then
        self.loaded = true
        self.load_time = string.format("%.2f ms", (end_time - require("plugman")._start) / 1e6)
        return true
    end
    logger.warn("Plugin aslready loaded")
    return nil
end

---Normalize plugin specification
---@param plugin_source string Plugin source URL or path
---@param plugin_spec table|string Plugin specification
---@param plugin_type string Type of plugin (e.g., 'git', 'local')
---@return PlugmanPlugin plugin specification
function M.normalize_plugin(plugin_source, plugin_spec, plugin_type)
    local result = vim.deepcopy(plugin_spec)
    local order = M._get_next_order()

    -- Extract plugin name and URL
    if type(result) == 'string' then
        result = { result }
    end

    -- Handle source
    if type(plugin_source) == 'string' then
        result.source = plugin_source
    elseif result[1] then
        result.source = result[1]
        result[1] = nil
    end

    -- Set basic properties
    result.order = order
    result.type = plugin_type or 'git'

    -- Extract name from source if not provided
    if result.source and not result.name then
        result.name = result.source:match('([^/]+)%.git$') or result.source:match('([^/]+)$')
    end

    -- Set default values
    result.lazy = result.lazy ~= false       -- lazy by default
    result.path = vim.fn.stdpath('data') .. '/site/pack/plugman/start/' .. result.name
    result.enabled = result.enabled ~= false -- enabled by default

    -- Create plugin object
    local plugin = Plugin:new(result)

    -- Log plugin details for debugging
    logger.debug(string.format('Normalized plugin: %s', vim.inspect(plugin)))

    return plugin
end

---Get next plugin order number
---@return number
function M._get_next_order()
    M._order = (M._order or 0) + 1
    return M._order
end

return M
--End-of-file--
