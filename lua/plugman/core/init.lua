local M = { order = 0 }

local utils = require("plugman.config.utils")
local logger = require("plugman.utils.logger")

function M:get_order()
    return self.order
end

function M:set_order(num)
    if num ~= nil then
        self.order = num
        return
    end
    self.order = self.order + 1
end

local Plugin = {}
Plugin.__index = Plugin
function Plugin:new(n_plugin)
    local plugin = setmetatable(vim.list_extend("force", vim.deepcopy(n_plugin), {
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

function M.normalize_plugin(plugin_source, plugin_spec, plugin_type)
    local result = vim.deepcopy(plugin_spec)
    M:set_order(M:get_order() + 1)

    -- Extract plugin name and URL
    if type(result) == 'string' then
        result = { result }
    end
    result.spec = plugin_spec

    if result[1] then
        assert(plugin_source == result[1], "Plugin source should be the same here...")
        result[1] = nil
    end

    result.order = M:get_order()
    result.type = plugin_type
    result.source = plugin_source

    if result.source and not result.name then
        result.name = result.source:match('([^/]+)%.git$') or result.source:match('([^/]+)$')
    end

    result.lazy = result.lazy or true -- lazy by default
    print(result.name)
    result.path = utils.get_plugin_path(result.name)

    return Plugin:new(result)
end

return M
