--Start-of-file--
local M = {}

local logger = require("plugman.utils.logger")

local Plugin = {}
Plugin.__index = Plugin

function Plugin:new(n_plugin)
    local plugin = setmetatable(vim.tbl_deep_extend("force", vim.deepcopy(n_plugin), {
        enabled = true,
        added = false,
        loaded = false,
        loading = false,
        load_time = nil,
        dependents = {},
    }), self)

    plugin:validate()
    return plugin
end

-- Helper functions
function Plugin:validate()
    local plugin = self
    if not plugin.name then
        logger.error("Plugin spec missing required 'name' field")
        return false
    end

    if not plugin.source then
        logger.error(string.format("Plugin %s missing required 'source' field", plugin.name))
        return false
    end

    -- Validate source format using utils
    local utils = require("plugman.utils")
    if not utils.is_valid_github_url(plugin.source) then
        logger.error(string.format("Plugin %s has invalid source format: %s", plugin.name, plugin.source))
        return false
    end

    return true
end

---Normalize plugin specification
---@param plugin_source string Plugin source URL or path
---@param plugin_spec table|string Plugin specification
---@param plugin_type string Type of plugin (e.g., 'git', 'local')
---@return table Normalized plugin specification
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
    result.lazy = result.lazy ~= false -- lazy by default
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