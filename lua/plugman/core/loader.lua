local M = {}

local logger = require('plugman.utils.logger')
local notify = require("plugman.utils.notify")

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
            pcall(opts.init)
        end

        -- Use MiniDeps to add the plugin
        local success, _ = pcall(MiniDeps.add, {
            source = opts.source,
            name = opts.name,
            depends = opts.depends,
            monitor = opts.monitor,
            checkout = opts.checkout,
            hooks = opts.hooks,
                -- pre_install = function()
                --     M._pre_install_hook(name, opts.hooks)
                -- end,
                -- pre_checkout = function()
                --     M._pre_checkout_hook(name, opts.hooks)
                -- end,
                -- post_install = function()
                --     M._post_install_hook(name, opts.hooks)
                -- end,
                -- post_checkout = function()
                --     M._post_checkout_hook(name, opts.hooks)
                -- end
            -- }
        })

        if not success then
            logger.error(string.format('Failed to load plugin: %s', name))
            notify.error(string.format('Failed to load %s', name))
            return
        end

        -- Setup plugin configuration
        -- Run config
        M._setup_plugin_config(name, opts)
        -- Setup keymaps
        M._setup_keymaps(name, opts)
        -- Run post function
        if opts.post then
            pcall(opts.post)
        end
    end)

    if not success then
        logger.error(string.format('Failed to load %s: %s', name, err))
        return false
    end

    logger.info(string.format('Successfully loaded: %s', name))
    return true
end

-- Possible hook names:
--     - <pre_install>   - before creating plugin directory.
--     - <post_install>  - after  creating plugin directory (before |:packadd|).
--     - <pre_checkout>  - before making change in existing plugin.
--     - <post_checkout> - after  making change in existing plugin.
--   Each hook is executed with the following table as an argument:
--     - <path> (`string`)   - absolute path to plugin's directory
--       (might not yet exist on disk).
--     - <source> (`string`) - resolved <source> from spec.
--     - <name> (`string`)   - resolved <name> from spec.

---Post install hook
---@param name string Plugin name
---@param opts PlugmanPlugin Plugin options
function M._pre_install_hook(name, opts)
    logger.info(string.format('Pre-install hook for %s', name))
    notify.info(string.format('Installed %s', name))

    if opts.hooks.pre_install then
        pcall(opts.hooks.pre_install)
    end
end

---Post checkout hook
---@param name string Plugin name
---@param opts PlugmanPlugin Plugin options
function M._pre_checkout_hook(name, opts)
    logger.info(string.format('Pre-checkout hook for %s', name))
    notify.info(string.format('Updated %s', name))

    if opts.hooks.pre_checkout then
        pcall(opts.hooks.pre_checkout)
    end
end

---Post install hook
---@param name string Plugin name
---@param opts PlugmanPlugin Plugin options
function M._post_install_hook(name, opts)
    logger.info(string.format('Post-install hook for %s', name))
    notify.info(string.format('Installed %s', name))

    if opts.hooks.post_install then
        pcall(opts.hooks.post_install)
    end
end

---Post checkout hook
---@param name string Plugin name
---@param opts PlugmanPlugin Plugin options
function M._post_checkout_hook(name, opts)
    logger.info(string.format('Post-checkout hook for %s', name))
    notify.info(string.format('Updated %s', name))

    if opts.hooks.post_checkout then
        pcall(opts.hooks.post_checkout)
    end
end

---Setup plugin configuration
---@param name string Plugin name
---@param opts PlugmanPlugin Plugin options
function M._setup_plugin_config(name, opts)
    if not opts.config then
        return
    end

    local success, err = pcall(function()
        if type(opts.config) == 'function' then
            opts.config()
        elseif type(opts.config) == 'string' then
            vim.cmd(opts.config)
        end
    end)

    if not success then
        logger.error(string.format('Failed to configure %s: %s', name, err))
        notify.error(string.format('Failed to configure %s', name))
    end
end

---Setup keymaps for plugin
---@param name string Plugin name
---@param opts PlugmanPlugin Plugin options
function M._setup_keymaps(name, opts)
    if not opts.keys then
        return
    end

    local keys = type(opts.keys) == 'table' and opts.keys or { opts.keys }

    for _, key in ipairs(keys) do
        if type(key) == 'string' then
            -- Simple keymap
            vim.keymap.set('n', key, '<cmd>echo "' .. name .. ' keymap"<cr>')
        elseif type(key) == 'table' then
            -- Complex keymap
            local mode = key.mode or 'n'
            local lhs = key[1] or key.lhs
            local rhs = key[2] or key.rhs
            local keyopts = key.opts or {}
            keyopts.desc = keyopts.desc or (name .. ' keymap')

            vim.keymap.set(mode, lhs, rhs, keyopts)
        end
    end
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

-- local Loader = {
--     load_queue = {},
--     current_load_state = {},
-- }

-- local Plugman = require("plugman")
-- local Logger = require("plugman.logger")
-- local utils = require("plugman.utils")

-- -- Plugin loading states
-- local LOAD_STATES = {
--     PENDING = "pending",
--     LOADING = "loading",
--     LOADED = "loaded",
--     FAILED = "failed"
-- }

-- function Loader:is_plugin_loaded(name)
--     return self.current_load_state[name] == LOAD_STATES.LOADED
-- end

-- function Loader:is_plugin_failed(name)
--     return self.current_load_state[name] == LOAD_STATES.FAILED
-- end

-- function Loader:is_plugin_pending(name)
--     return self.current_load_state[name] == LOAD_STATES.PENDING
-- end

-- function Loader:update_load_state(name, state)
--     self.current_load_state[name] = state
--     Logger:debug("Plugin %s state updated to %s", name, state)
-- end

-- function Loader.should_load(plugin_config)
--     return not plugin_config.loaded and utils.validate_plugin(plugin_config)
-- end

-- -- Plugin loading functions
-- function Loader:load_plugin(plugin_name)
--     Logger.start_profile("load_plugin_" .. plugin_name)
--     local plugin_config = Plugman.plugins[plugin_name]

--     -- if plugin.loaded or not self:should_load(plugin, trigger_type) then
--     if Loader.should_load(plugin_config) then
--         self:update_load_state(plugin_config.name, LOAD_STATES.LOADED)
--         Logger.end_profile("load_plugin_" .. plugin_config.name)
--         return true
--     end

--     if not utils.validate_plugin(plugin_config) then
--         self:update_load_state(plugin_config.name, LOAD_STATES.FAILED)
--         Logger.end_profile("load_plugin_" .. plugin_config.name)
--         return false
--     end

--     self:update_load_state(plugin_config.name, LOAD_STATES.LOADING)

--     -- Check dependencies first
--     if plugin_config.depends then
--         for _, dep in ipairs(plugin_config.depends) do
--             if not Loader:load_plugin(dep) then
--                 vim.notify(
--                     string.format('Failed to load dependency %s for %s', dep, plugin_name),
--                     vim.log.levels.ERROR
--                 )
--                 return false
--             end
--         end
--     end

--     -- if self.plugin_cache[plugin.name] then
--     --     Logger:debug("Plugin %s found in cache", plugin.name)
--     --     self:update_load_state(plugin.name, LOAD_STATES.LOADED)
--     --     Logger.end_profile("load_plugin_" .. plugin.name)
--     --     return true
--     -- end

--     local ok, err = pcall(function()
--         -- Use MiniDeps for actual loading
--         if plugin_config.source then
--             MiniDeps.add({
--                 name = plugin_config.name,
--                 source = plugin_config.source,
--                 checkout = plugin_config.spec.checkout,
--                 depends = plugin_config.spec.depends,
--                 hooks = plugin_config.spec.hooks,
--                 monitor = plugin_config.spec.monitor,
--             })
--         end

--         self:setup_lazy_loading(plugin_config)
--         -- Run plugin configuration
--         if plugin_config.config then
--             if type(plugin_config.config) == 'function' then
--                 plugin_config.config()
--             elseif type(plugin_config.config) == 'string' then
--                 vim.cmd(plugin_config.config)
--             end
--         end

--         -- -- Setup plugin-specific commands
--         -- if plugin_config.commands then
--         --     M.setup_commands(plugin_name, plugin_config.commands)
--         -- end

--         -- -- Setup filetype associations
--         -- if plugin_config.filetypes then
--         --     M.setup_filetypes(plugin_name, plugin_config.filetypes)
--         -- end
--     end)

--     if ok then
--         Plugman.loaded[plugin_name] = true
--         self:update_load_state(plugin_config.name, LOAD_STATES.LOADED)
--         Logger:info("Plugin %s loaded successfully", plugin_config.name)
--     else
--         self:update_load_state(plugin_config.name, LOAD_STATES.FAILED)
--         Logger:error("Failed to load plugin %s: %s", plugin_config.name, err)
--     end
--     Logger.end_profile("load_plugin_" .. plugin_config.name)
--     return ok
-- end

-- -- Lazy loading implementation
-- function Loader:setup_lazy_loading(plugin)
--     if plugin.spec.cmd then
--         self:setup_command_loading(plugin)
--     end

--     if plugin.spec.event then
--         self:setup_event_loading(plugin)
--     end

--     if plugin.spec.ft then
--         self:setup_filetype_loading(plugin)
--     end
-- end

-- function Loader:setup_event_loading(plugin)
--     local Events = require("plugman.events")
--     for _, event in ipairs(self.spec.event) do
--         Events:register_plugin_event(plugin, event, function()
--             local success = pcall(function()
--                 plugin:load()
--             end)
--             if success then
--                 return true
--             end
--         end)
--     end
-- end

-- function Loader:setup_command_loading(plugin)
--     for _, cmd in ipairs(plugin.spec.cmd) do
--         vim.api.nvim_create_user_command(cmd, function(opts)
--             self:load()
--             vim.schedule(function()
--                 vim.cmd(cmd .. " " .. (opts.args or ""))
--             end)
--         end, { nargs = "*" })
--     end
-- end

-- function Loader:setup_filetype_loading(plugin)
--     for _, ft in ipairs(plugin.spec.ft) do
--         vim.api.nvim_create_autocmd("FileType", {
--             pattern = ft,
--             callback = function()
--                 self:load()
--             end
--         })
--     end
-- end


-- -- Queue management
-- function Loader:add_to_queue(plugin)
--     if not self:is_plugin_pending(plugin.name) then
--         table.insert(self.load_queue, plugin)
--         self:update_load_state(plugin.name, LOAD_STATES.PENDING)
--         Logger:debug("Plugin %s added to load queue", plugin.name)
--     end
-- end

-- function Loader:process_queue()
--     Logger.start_profile("process_queue")

--     local success_count = 0
--     local fail_count = 0

--     for _, plugin in ipairs(self.load_queue) do
--         if self:is_plugin_pending(plugin.name) then
--             if self.load_plugin(plugin) then
--                 success_count = success_count + 1
--             else
--                 fail_count = fail_count + 1
--             end
--         end
--     end

--     -- Clear processed plugins from queue
--     self.load_queue = {}

--     Logger:info("Queue processing complete: %d succeeded, %d failed", success_count, fail_count)
--     Logger.end_profile("process_queue")

--     return success_count, fail_count
-- end

-- function Loader:unload_plugin(name)
--     if self:is_plugin_loaded(name) then
--         local success = pcall(function()
--             require("mini.deps").clean(name)
--         end)

--         if success then
--             self.plugin_cache[name] = nil
--             self.current_load_state[name] = nil
--             Logger:info("Plugin %s unloaded successfully", name)
--         else
--             Logger:error("Failed to unload plugin %s", name)
--         end

--         return success
--     end
--     return false
-- end

-- function Loader:reload_plugin(name)
--     if self:unload_plugin(name) then
--         return self:load_plugin(self.plugin_cache[name])
--     end
--     return false
-- end

-- -- State queries
-- function Loader:get_plugin_state(name)
--     return self.current_load_state[name]
-- end

-- function Loader:get_loaded_plugins()
--     local loaded = {}
--     for name, state in pairs(self.current_load_state) do
--         if state == LOAD_STATES.LOADED then
--             table.insert(loaded, name)
--         end
--     end
--     return loaded
-- end

-- function Loader:get_failed_plugins()
--     local failed = {}
--     for name, state in pairs(self.current_load_state) do
--         if state == LOAD_STATES.FAILED then
--             table.insert(failed, name)
--         end
--     end
--     return failed
-- end

-- function Loader:get_pending_plugins()
--     local pending = {}
--     for name, state in pairs(self.current_load_state) do
--         if state == LOAD_STATES.PENDING then
--             table.insert(pending, name)
--         end
--     end
--     return pending
-- end

-- -- Cache management
-- function Loader:clear_cache()
--     self.plugin_cache = {}
--     Logger:info("Plugin cache cleared")
-- end

-- function Loader:get_cache_size()
--     return #self.plugin_cache
-- end

-- return Loader
