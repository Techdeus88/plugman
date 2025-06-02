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
        logger:error("Plugin spec missing required 'name' field")
        return false
    end

    if not plugin.source then
        logger:error("Plugin %s missing required 'source' field", plugin.name)
        return false
    end
    -- if plugin.depends then
    --     for _, dependency in ipairs(plugin.depends) do
    --         if not plugin_registry[dependency] then
    --             logger:error("Plugin %s has unresolved dependency: %s", plugin.name, dependency)
    --             return false
    --         end
    --     end
    -- end
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
    result.spec = plugin_spec

    if result[1] then
        assert(plugin_source == result[1], "Plugin source should be the same here...")
        result[1] = nil
    end

    result.order = order
    result.type = plugin_type
    result.source = plugin_source

    if result.source and not result.name then
        result.name = result.source:match('([^/]+)%.git$') or result.source:match('([^/]+)$')
    end

    result.lazy = result.lazy or true -- lazy by default
    result.path = vim.fn.stdpath('data') .. '/site/pack/plugman/start/' .. result.name

    return Plugin:new(result)
end

---Get next plugin order number
---@return number
function M._get_next_order()
    M._order = (M._order or 0) + 1
    return M._order
end
return M
