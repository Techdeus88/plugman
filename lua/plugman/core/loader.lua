local M = {}

local logger = require('plugman.utils.logger')

---Load plugins in priority order
---@param plugins table<string, PlugmanPlugin>
---@return table<string, boolean> Success status for each plugin
function M.load_by_priority(plugins)
    -- Sort plugins by priority
    local sorted_plugins = {}
    for name, opts in pairs(plugins) do
        table.insert(sorted_plugins, { name = name, opts = opts })
    end

    table.sort(sorted_plugins, function(a, b)
        local priority_a = a.opts.priority or 50
        local priority_b = b.opts.priority or 50
        return priority_a > priority_b
    end)

    local results = {}

    -- Load plugins in order
    for _, plugin in ipairs(sorted_plugins) do
        local success = M.load_plugin(plugin.name, plugin.opts)
        results[plugin.name] = success
    end

    return results
end

---Load a single plugin
---@param name string Plugin name
---@param opts PlugmanPlugin Plugin options
---@return boolean Success status
function M.load_plugin(name, opts)
    logger.debug(string.format('Loading plugin: %s', name))

    local success, err = pcall(function()
        -- Load dependencies first
        if opts.depends then
            for _, dep in ipairs(opts.depends) do
                M.ensure_dependency_loaded(dep)
            end
        end

        -- Run init function
        if opts.init then
            opts.init()
        end

        -- Actually load the plugin
        -- This would integrate with MiniDeps

        -- Run config
        if opts.config then
            if type(opts.config) == 'function' then
                opts.config()
            end
        end

        -- Run post function
        if opts.post then
            opts.post()
        end
    end)

    if not success then
        logger.error(string.format('Failed to load %s: %s', name, err))
        return false
    end

    logger.info(string.format('Successfully loaded: %s', name))
    return true
end

---Ensure dependency is loaded
---@param dep_name string Dependency name
function M.ensure_dependency_loaded(dep_name)
    -- Check if dependency is already loaded
    local plugman = require('plugman')
    if plugman._loaded[dep_name] then
        return
    end

    -- Try to load dependency
    if plugman._plugins[dep_name] then
        M.load_plugin(dep_name, plugman._plugins[dep_name])
    else
        logger.warn(string.format('Dependency %s not found', dep_name))
    end
end

return M