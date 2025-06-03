--Start-of-file--
local M = {}

local utils = require("plugman.utils")
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
        local success = M.load_plugin(plugin)
        results[plugin.name] = success
    end
    return results
end

---Load a single plugin
---@param plugin PlugmanPlugin plugin
---@return boolean Success status
function M.load_plugin(plugin)
    local mini_deps = require("plugman.core.bootstrap")
    logger.debug(string.format('Loading plugin: %s (source: %s)', plugin.name, plugin.source))

    local success, err = pcall(function()
        -- Load dependencies first
        if plugin.depends then
            for _, dep in ipairs(plugin.depends) do
                M.ensure_dependency_loaded(dep)
            end
        end

        -- Run init function
        if plugin.init then
            local init_success, init_err = pcall(plugin.init)
            if not init_success then
                logger.error(string.format('Failed to run init for %s: %s', plugin.name, init_err))
            end
        end

        -- Use MiniDeps to add the plugin
        logger.debug(string.format('Adding plugin to MiniDeps: %s', vim.inspect(plugin)))
        local deps_success, deps_err = pcall(mini_deps.add, {
            source = plugin.source,
            depends = plugin.depends,
            monitor = plugin.monitor,
            checkout = plugin.checkout,
            hooks = plugin.hooks,
        })

        if not deps_success then
            logger.error(string.format('Failed to add plugin to MiniDeps: %s', deps_err))
            notify.error(string.format('Failed to load %s', plugin.name))
            return
        end

        -- Setup plugin configuration
        M._setup_plugin_config(plugin)
        -- Setup keymaps
        M._setup_keymaps(plugin)
        -- Run post function
        if plugin.post then
            local post_success, post_err = pcall(plugin.post)
            if not post_success then
                logger.error(string.format('Failed to run post for %s: %s', plugin.name, post_err))
            end
        end
    end)

    if not success then
        logger.error(string.format('Failed to load %s: %s', plugin.name, err))
        return false
    end

    logger.info(string.format('Successfully loaded: %s', plugin.name))
    return true
end

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

-- Constants
local SETUP_PHASES = {
    {
        name = 'init',
        condition = function(c) return c.init ~= nil end,
        action = function(c) c.init() end,
        timing = 'now'
    },
    {
        name = 'config',
        condition = function(c) return (c.config ~= nil) or (c.opts ~= nil) end,
        action = function(c)
            local merged_opts = M._merge_config(c)
            M._process_config(c, merged_opts)
        end,
        timing = 'dynamic'
    },
    {
        name = 'keys',
        condition = function(c) return c.keys ~= nil end,
        action = function(c) M._setup_keymaps(c) end,
        timing = 'later'
    },
    {
        name = 'post',
        condition = function(c) return c.post ~= nil end,
        action = function(c) c.post() end,
        timing = 'later'
    }
}

function M.setup_with_boolean(opts)
    return opts
end

function M.setup_with_opts(plugin, opts)
    local mod_name = plugin.require or plugin.name
    local ok, mod = pcall(require, mod_name)
    if not ok then
        vim.notify(string.format('Failed to require plugin: ', plugin.name), vim.log.levels.ERROR,
            { title = "Techdeus IDE Error" })
        return
    end
    return mod.setup(opts)
end

function M.setup_with_string(config)
    vim.cmd(config)
end

-- Configuration Processing
function M._merge_config(plugin)
    if not (plugin.config or plugin.opts) then return {} end

    local default_opts = type(plugin.opts) == 'table' and plugin.opts or {}
    local config_opts = type(plugin.config) == 'table' and plugin.config or {}

    return vim.tbl_deep_extend('force', default_opts, config_opts)
end

function M._process_config(plugin, merged_opts)
    if type(plugin.config(plugin, merged_opts)) then
        return plugin.config(plugin, merged_opts)
    elseif type(plugin.config) == 'boolean' then
        return M.setup_with_boolean(plugin.config)
    elseif type(plugin.config) == 'string' then
        return M.setup_with_string(plugin.config)
    elseif merged_opts then
        return M.setup_with_opts(plugin, merged_opts)
    end
end

---Setup plugin configuration
---@param plugin PlugmanPlugin Plugin
function M._setup_plugin_config(plugin)
    if not plugin.config then
        return
    end
    -- Process setup phases
    for _, phase in ipairs(SETUP_PHASES) do
        if phase.condition(plugin) then
            local timing_fn = utils.get_timing_function(plugin, phase)
            timing_fn(function()
                utils.safe_pcall(phase.action, plugin)
                vim.notify(string.format("Phase %s completed for %s", phase.name, plugin.name), "plugins")
            end)
        end
    end

    local success, err = pcall(
        function()
            local merged_opts = M.merge_config(plugin.config)
            M.process_config(plugin, merged_opts)
        end)

    if not success then
        logger.error(string.format('Failed to configure %s: %s', plugin.name, err))
        notify.error(string.format('Failed to configure %s', plugin.name))
    end
end

---Setup keymaps for plugin
---@param plugin PlugmanPlugin Plugin
function M._setup_keymaps(plugin)
    local module_keys = plugin.keys
    if not module_keys or type(module_keys) ~= "table" and type(module_keys) ~= "function" then
        error "Keys must be a table or function"
        return false
    end

    local keys = type(module_keys) == "function" and (pcall(module_keys)) or module_keys
    if type(keys) ~= "table" then
        vim.notify(string.format("Invalid keys format for %s", plugin.name), "plugins")
        return
    end

    for _, keymap in ipairs(keys) do
        if type(keymap) ~= "table" or not keymap[1] then
            vim.notify(string.format("Invalid keymap entry for %s", plugin.name), "plugins")
        else
            local opts = {
                buffer = keymap.buffer,
                desc = keymap.desc,
                silent = keymap.silent ~= false,
                remap = keymap.remap,
                noremap = keymap.noremap ~= false,
                nowait = keymap.nowait,
                expr = keymap.expr,
            }
            for _, mode in ipairs(keymap.mode or { "n" }) do
                vim.keymap.set(mode, keymap[1], keymap[2], opts)
            end
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

---Load a single module file
---@param file_path string Path to the module file
---@return table|nil Module configuration
local function load_file(file_path)
    logger.debug(string.format('Attempting to load file: %s', file_path))
    local success, module_configs = pcall(dofile, file_path)
    if not success then
        logger.error(string.format('Failed to load module file %s: %s', file_path, module_configs))
        return nil
    end
    logger.debug(string.format('Successfully loaded file: %s', file_path))
    logger.debug(string.format('File contents: %s', vim.inspect(module_configs)))
    return module_configs
end

---Load plugin configurations from a directory
---@param dir_path string Path to the directory containing plugin files
---@return table Plugin configurations
function M.load_plugin_files(dir_path)
    local plugins = {}

    -- Check if directory exists
    if vim.fn.isdirectory(dir_path) == 0 then
        logger.warn(string.format('Directory does not exist: %s', dir_path))
        return plugins
    end

    -- Get all files in directory
    local files = vim.fn.glob(dir_path .. '/*.lua', false, true)
    logger.debug(string.format('Found %d files in %s', #files, dir_path))
    logger.debug(string.format('Files found: %s', vim.inspect(files)))

    -- Process each file
    for _, file_path in ipairs(files) do
        logger.debug(string.format('Processing file: %s', file_path))
        local plugin_configs = load_file(file_path)
        if plugin_configs then
            -- Handle single plugin config
            if type(plugin_configs[1]) == "string" then
                logger.debug(string.format('Found string config: %s', plugin_configs[1]))
                if utils.is_valid_github_url(plugin_configs[1]) then
                    -- Convert boolean values
                    plugin_configs.lazy = utils.to_boolean(plugin_configs.lazy)
                    plugin_configs.source = plugin_configs[1]
                    plugin_configs.name = plugin_configs.name or plugin_configs[1]:match('([^/]+)$')
                    logger.debug(string.format('Adding plugin: %s', vim.inspect(plugin_configs)))
                    table.insert(plugins, plugin_configs)
                else
                    logger.warn(string.format('Invalid GitHub URL: %s', plugin_configs[1]))
                end
                -- Handle table of plugins
            elseif type(plugin_configs) == 'table' then
                logger.debug(string.format('Found table config: %s', vim.inspect(plugin_configs)))
                for _, plugin_config in ipairs(plugin_configs) do
                    if type(plugin_config[1]) == "string" then
                        logger.debug(string.format('Found string in table: %s', plugin_config[1]))
                        if utils.is_valid_github_url(plugin_config[1]) then
                            -- Convert boolean values
                            plugin_config.lazy = utils.to_boolean(plugin_config.lazy)
                            plugin_config.source = plugin_config[1]
                            plugin_config.name = plugin_config.name or plugin_config[1]:match('([^/]+)$')
                            logger.debug(string.format('Adding plugin from table: %s', vim.inspect(plugin_config)))
                            table.insert(plugins, plugin_config)
                        else
                            logger.warn(string.format('Invalid GitHub URL in table: %s', plugin_config[1]))
                        end
                    else
                        logger.warn(string.format('Invalid plugin config in table: %s', vim.inspect(plugin_config)))
                    end
                end
            else
                logger.warn(string.format('Invalid plugin config type: %s', type(plugin_configs)))
            end
        end
    end

    logger.info(string.format('Loaded %d plugins from %s', #plugins, dir_path))
    logger.debug(string.format('Final plugins list: %s', vim.inspect(plugins)))
    return plugins
end

---Load all plugins from configured directories
---@param paths table Configuration containing paths
---@return table All loaded plugins
function M.load_all(paths)
    local all_plugins = {}

    if not paths then
        logger.error('No paths provided to load_all')
        return all_plugins
    end

    logger.debug(string.format('Loading plugins with paths: %s', vim.inspect(paths)))

    -- Load from modules directory if configured
    if paths.modules_path then
        logger.info(string.format('Loading from modules directory: %s', paths.modules_path))
        local modules = M.load_plugin_files(paths.modules_path)
        if #modules > 0 then
            logger.debug(string.format('Adding %d modules to all_plugins', #modules))
            vim.list_extend(all_plugins, modules)
        end
    else
        logger.warn('No modules_path configured')
    end

    -- Load from plugins directory if configured
    if paths.plugins_path then
        logger.info(string.format('Loading from plugins directory: %s', paths.plugins_path))
        local plugins = M.load_plugin_files(paths.plugins_path)
        if #plugins > 0 then
            logger.debug(string.format('Adding %d plugins to all_plugins', #plugins))
            vim.list_extend(all_plugins, plugins)
        end
    else
        logger.warn('No plugins_path configured')
    end

    logger.info(string.format('Total plugins loaded: %d', #all_plugins))
    logger.debug(string.format('All loaded plugins: %s', vim.inspect(all_plugins)))
    return all_plugins
end

return M
--End-of-file--
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
