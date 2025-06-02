local M = {}

local cache_file = vim.fn.stdpath('cache') .. '/plugman_cache.json'
local cache_data = {}

---Setup cache system
---@param opts table Cache options
function M.setup(opts)
    opts = opts or {}

    -- Load existing cache
    M.load()

    -- Auto-save on exit
    vim.api.nvim_create_autocmd('VimLeavePre', {
        callback = function()
            M.save()
        end
    })
end

---Load cache from file
function M.load()
    local file = io.open(cache_file, 'r')
    if file then
        local content = file:read('*all')
        file:close()

        local success, data = pcall(vim.json.decode, content)
        if success then
            cache_data = data
        end
    end
end

---Save cache to file
function M.save()
    local file = io.open(cache_file, 'w')
    if file then
        file:write(vim.json.encode(cache_data))
        file:close()
    end
end

---Set plugin loaded state
---@param name string Plugin name
---@param loaded boolean Loaded state
function M.set_plugin_loaded(name, loaded)
    cache_data.plugins = cache_data.plugins or {}
    cache_data.plugins[name] = cache_data.plugins[name] or {}
    cache_data.plugins[name].loaded = loaded
    cache_data.plugins[name].last_loaded = os.time()
end

---Get plugin from cache
---@param name string Plugin name
---@return table|nil
function M.get_plugin(name)
    return cache_data.plugins and cache_data.plugins[name]
end

---Remove plugin from cache
---@param name string Plugin name
function M.remove_plugin(name)
    if cache_data.plugins then
        cache_data.plugins[name] = nil
    end
end

---Clear all cache
function M.clear()
    cache_data = {}
    M.save()
end

return M