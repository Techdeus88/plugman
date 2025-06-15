local Bootstrap = require("plugman.core.bootstrap")
local Plugin = require('plugman.core.plugin')
local Cache = require('plugman.core.cache')
local Logger = require('plugman.utils.logger')
local Notify = require('plugman.utils.notify')
local Messages = require("plugman.utils.message_handler")

---@class PlugmanManager
local Manager = {}
Manager.__index = Manager

---Create new manager instance
---@param config table Configuration
---@return PlugmanManager
function Manager.new(config)
  ---@class PlugmanManager
  local self = setmetatable({}, Manager)

  self.config = config
  self.plugins = {}
  self.cache = Cache.new(config)
  self.loaded_plugins = {}
  self.pending_plugins = {}
  self.load_order_counter = 0
  -- Global load order counte
  -- Bootstrap and ensure MiniDeps is installed and setup
  Bootstrap.init(config.mini_deps)
  return self
end

---Add plugin from spec
---@param spec table|string Plugin specification
---@return PlugmanPlugin
function Manager:add_spec(spec)
  Logger.debug(string.format("Converting spec to plugin: %s", vim.inspect(spec)))
  local plugin = Plugin.from_spec(spec)
  Logger.debug(string.format("Created plugin: %s", vim.inspect(plugin)))
  return self:add_plugin(plugin)
end

---Add plugin
---@param type string Plugin type (plugin or dependency)
---@param source string Plugin source
---@param opts table Plugin options
---@return PlugmanPlugin
function Manager:add(source, opts, type)
  local plugin = Plugin.new(source, opts or {}, type)
  return self:add_plugin(plugin)
end

---Add plugin instance
---@param plugin PlugmanPlugin
---@return PlugmanPlugin
function Manager:add_plugin(plugin)
  if self.plugins[plugin.name] then
    Logger.warn("Plugin already exists: " .. plugin.name)
    return self.plugins[plugin.name]
  end

  Logger.debug(string.format("Adding plugin to manager: %s", vim.inspect(plugin)))
  self.plugins[plugin.name] = plugin

  -- Cache plugin info
  self.cache:set_plugin(plugin.name, plugin:to_cache())

  Logger.info("Added plugin: " .. plugin.name)
  return plugin
end

---Remove plugin
---@param name string Plugin name
---@return boolean Success
function Manager:remove(name)
  local plugin = self.plugins[name]
  if not plugin then
    Logger.warn("Plugin not found: " .. name)
    return false
  end

  -- Remove from MiniDeps
  if plugin.installed then
    MiniDeps.remove(plugin.source)
  end

  -- Clean up
  self.plugins[name] = nil
  self.loaded_plugins[name] = nil
  self.cache:remove_plugin(name)

  Logger.info("Removed plugin: " .. name)
  Notify.info("Removed: " .. name)

  return true
end

---Update plugins
---@param names table|nil Plugin names to update
---@return table Results
function Manager:update(names)
  local to_update = names or vim.tbl_keys(self.plugins)
  local results = {}

  for _, name in ipairs(to_update) do
    local plugin = self.plugins[name]
    if plugin and plugin.installed then
      local ok, err = pcall(MiniDeps.update, plugin.source)
      results[name] = {
        success = ok,
        error = err
      }

      if ok then
        Logger.info("Updated plugin: " .. name)
      else
        Logger.error("Failed to update plugin: " .. name .. " - " .. tostring(err))
      end
    end
  end

  Notify.info("Update completed for " .. #to_update .. " plugins")
  return results
end

---Install plugin
---@param plugin PlugmanPlugin
---@return boolean Success
function Manager:install(plugin)
  if plugin.installed then
    return true
  end

  local ok, err = Bootstrap.add({
    source = plugin.source,
    depends = plugin.depends,
    hooks = plugin.hooks,
    checkout = plugin.checkout,
    monitor = plugin.monitor,
  })

  if ok then
    plugin.installed = plugin:is_installed()
    plugin.added = true
    self.cache:set_plugin(plugin.name, plugin:to_cache())
    return true
  else
    return false
  end
end

---Load plugin
---@param plugin PlugmanPlugin
---@return boolean Success
function Manager:load(plugin)
  if self.loaded_plugins[plugin.name] then
    return true
  end
  self.load_order_counter = self.load_order_counter + 1

  -- Install if not installed
  if not plugin.added then
    if not self:install(plugin) then
      return false
    end
  end

  if not plugin.loaded then
    Logger.info("Loading plugin: " .. plugin.name)
    -- Run init hook
    if plugin.init then
      local ok, err = pcall(plugin.init)
      if not ok then
        Logger.error("Plugin init failed: " .. plugin.name .. " - " .. tostring(err))
      end
    end
    -- Handle configuration
    if plugin.config or plugin.opts then
      local merged_opts = self._merge_config(plugin)
      self._process_config(plugin, merged_opts)
    end
    -- Setup keymaps
    if plugin.keys then
      self.setup_keymaps(plugin)
    end
    -- Run post hook
    if plugin.post then
      local post_ok, post_err = pcall(plugin.post)
      if not post_ok then
        Logger.error("Plugin post hook failed: " .. plugin.name .. " - " .. tostring(post_err))
      end
    end

    self.loaded_plugins[plugin.name] = true
    plugin.loaded = true
    plugin.load_order = self.load_order_counter

    Logger.info("Loaded plugin: " .. plugin.name)
    return true
  else
    Logger.warn("Plugin already loaded " .. plugin.name)
    return false
  end
end

---Setup keymaps for plugin
---@param plugin PlugmanPlugin
function Manager.setup_keymaps(plugin)
  local keys = type(plugin.keys) == "function" and plugin.keys() or plugin.keys
  if type(keys) ~= "table" then
    Logger.error(string.format("Invalid keys format for %s", plugin.name))
    return
  end

  for _, keymap in ipairs(keys) do
    if type(keymap) == "table" and keymap[1] then
      local opts = {
        buffer = keymap.buffer,
        desc = keymap.desc,
        silent = keymap.silent ~= false,
        remap = keymap.remap,
        noremap = keymap.noremap ~= false,
        nowait = keymap.nowait,
        expr = keymap.expr,
      }
      local lhs = keymap.lhs or keymap[1]
      local rhs = keymap.rhs or keymap[2]

      for _, mode in ipairs(keymap.mode or { "n" }) do
        vim.keymap.set(mode, lhs, rhs, opts)
      end
    else
      Logger.warn(string.format("Invalid keymap entry for %s", plugin.name))
    end
  end
end

-- Configuration Functions
function Manager._merge_config(plugin)
  if not (plugin.config or plugin.opts) then return {} end

  local default_opts = type(plugin.opts) == 'table' and plugin.opts or {}
  local config_opts = type(plugin.config) == 'table' and plugin.config or {}

  return vim.tbl_deep_extend('force', default_opts, config_opts)
end

function Manager._process_config(plugin, merged_opts)
  if not plugin then return end

  if type(plugin.config) == 'function' then
    return plugin.config(plugin, merged_opts)
  elseif type(plugin.config) == 'boolean' then
    return plugin.config
  elseif type(plugin.config) == 'string' then
    return vim.cmd(plugin.config)
  elseif merged_opts then
    local mod_name = plugin.require or plugin.name
    local ok, mod = pcall(require, mod_name)
    if ok and mod.setup then
      return mod.setup(merged_opts)
    else
      Messages.plugin(plugin.name, 'ERROR', string.format('Failed to require plugin: %s', mod_name))
    end
  end
end

---Get plugin status
---@param name string Plugin name
---@return table|nil Status
function Manager:status(name)
  local plugin = self.plugins[name]
  if not plugin then
    return nil
  end

  return {
    name = plugin.name,
    source = plugin.source,
    installed = plugin.installed,
    loaded = plugin.loaded,
    lazy = plugin.lazy,
    enabled = plugin.enabled,
    priority = plugin.priority,
  }
end

---Get all plugins
---@return table<string, PlugmanPlugin>
function Manager:get_plugins()
  return self.plugins
end

---Install multiple plugins in parallel
---@param plugins table<PlugmanPlugin> List of plugins to install
---@return table<string, boolean> Results map of plugin names to success status
function Manager:install_batch(plugins)
  if not plugins or #plugins == 0 then
    return {}
  end

  local results = {}
  local max_parallel = self.config.performance.max_parallel or 4
  
  -- Group plugins by priority and dependencies
  local priority_plugins = {}
  local independent_plugins = {}
  local dependent_plugins = {}
  
  for _, plugin in ipairs(plugins) do
    if plugin.priority and plugin.priority > 0 then
      table.insert(priority_plugins, plugin)
    elseif not plugin.depends or #plugin.depends == 0 then
      table.insert(independent_plugins, plugin)
    else
      table.insert(dependent_plugins, plugin)
    end
  end

  -- Sort priority plugins by priority (highest first)
  table.sort(priority_plugins, function(a, b)
    return a.priority > b.priority
  end)

  -- Install priority plugins in parallel as the first batch
  if #priority_plugins > 0 then
    local function install_plugin(plugin)
      local ok, err = pcall(function()
        MiniDeps.add({
          source = plugin.source,
          depends = plugin.depends,
          hooks = plugin.hooks,
          checkout = plugin.checkout,
          monitor = plugin.monitor,
        })
      end)

      if ok then
        plugin.installed = plugin:is_installed()
        plugin.added = true
        self.cache:set_plugin(plugin.name, plugin:to_cache())
        Logger.info("Installed priority plugin: " .. plugin.name)
        results[plugin.name] = true
        -- Optionally load immediately
        self:load(plugin)
      else
        Logger.error("Failed to install priority plugin: " .. plugin.name .. " - " .. tostring(err))
        Notify.error("Failed to install priority plugin: " .. plugin.name)
        results[plugin.name] = false
      end
    end

    for i = 1, #priority_plugins, max_parallel do
      local batch = {}
      for j = i, math.min(i + max_parallel - 1, #priority_plugins) do
        table.insert(batch, priority_plugins[j])
      end

      local threads = {}
      for _, plugin in ipairs(batch) do
        table.insert(threads, coroutine.create(function()
          install_plugin(plugin)
        end))
      end

      local running = true
      while running do
        running = false
        for _, thread in ipairs(threads) do
          if coroutine.status(thread) ~= "dead" then
            running = true
            coroutine.resume(thread)
          end
        end
      end
    end
  end

  -- Then install independent plugins in parallel
  if #independent_plugins > 0 then
    local function install_plugin(plugin)
      local ok, err = pcall(function()
        MiniDeps.add({
          source = plugin.source,
          depends = plugin.depends,
          hooks = plugin.hooks,
          checkout = plugin.checkout,
          monitor = plugin.monitor,
        })
      end)

      if ok then
        plugin.installed = plugin:is_installed()
        plugin.added = true
        self.cache:set_plugin(plugin.name, plugin:to_cache())
        Logger.info("Installed plugin: " .. plugin.name)
        results[plugin.name] = true
      else
        Logger.error("Failed to install plugin: " .. plugin.name .. " - " .. tostring(err))
        Notify.error("Failed to install: " .. plugin.name)
        results[plugin.name] = false
      end
    end

    -- Process plugins in batches
    for i = 1, #independent_plugins, max_parallel do
      local batch = {}
      for j = i, math.min(i + max_parallel - 1, #independent_plugins) do
        table.insert(batch, independent_plugins[j])
      end
      
      -- Create a coroutine for each plugin in the batch
      local threads = {}
      for _, plugin in ipairs(batch) do
        table.insert(threads, coroutine.create(function()
          install_plugin(plugin)
        end))
      end
      
      -- Run the batch of coroutines
      local running = true
      while running do
        running = false
        for _, thread in ipairs(threads) do
          if coroutine.status(thread) ~= "dead" then
            running = true
            coroutine.resume(thread)
          end
        end
      end
    end
  end

  -- Finally install dependent plugins sequentially
  for _, plugin in ipairs(dependent_plugins) do
    local ok, err = pcall(function()
      MiniDeps.add({
        source = plugin.source,
        depends = plugin.depends,
        hooks = plugin.hooks,
        checkout = plugin.checkout,
        monitor = plugin.monitor,
      })
    end)

    if ok then
      plugin.installed = plugin:is_installed()
      plugin.added = true
      self.cache:set_plugin(plugin.name, plugin:to_cache())
      Logger.info("Installed dependent plugin: " .. plugin.name)
      results[plugin.name] = true
    else
      Logger.error("Failed to install dependent plugin: " .. plugin.name .. " - " .. tostring(err))
      Notify.error("Failed to install dependent plugin: " .. plugin.name)
      results[plugin.name] = false
    end
  end

  return results
end

return Manager




-- -- Add plugin to state
-- function M.add_plugin(state, plugin)
--   state.plugins[plugin.name] = plugin

--   -- Categorize by loading strategy
--   if plugin.priority > 0 then
--     table.insert(state.loading_order.priority, plugin)
--     -- Sort by priority (higher first)
--     table.sort(state.loading_order.priority, function(a, b)
--       return a.priority > b.priority
--     end)
--   elseif plugin.lazy then
--     table.insert(state.loading_order.lazy, plugin)
--   else
--     table.insert(state.loading_order.normal, plugin)
--   end

--   logger.debug("Added plugin: " .. plugin.name .. " (lazy: " .. tostring(plugin.lazy) .. ")")
-- end

-- -- Install all plugins
-- function M.install_all(state)
--   local minideps = require('mini.deps')

--   notify.info("Installing plugins...")

--   local count = 0
--   for name, plugin in pairs(state.plugins) do
--     if not plugin.installed then
--       logger.info("Installing: " .. name)

--       local spec = plugin:get_minideps_spec()
--       minideps.add(spec)

--       plugin.installed = true
--       count = count + 1
--     end
--   end

--   if count > 0 then
--     notify.info("Installed " .. count .. " plugins")
--   else
--     notify.info("All plugins already installed")
--   end
-- end

-- -- Update all plugins
-- function M.update_all(state)
--   local minideps = require('mini.deps')

--   notify.info("Updating plugins...")

--   for name, plugin in pairs(state.plugins) do
--     if plugin.installed then
--       logger.info("Updating: " .. name)
--       minideps.update(plugin.name)
--     end
--   end

--   notify.info("Plugin updates completed")
-- end

-- -- Clean unused plugins
-- function M.clean(state)
--   local minideps = require('mini.deps')

--   notify.info("Cleaning unused plugins...")

--   -- Get list of installed plugins
--   local installed = minideps.get_session()
--   local managed = {}

--   for name, _ in pairs(state.plugins) do
--     managed[name] = true
--   end

--   local cleaned = 0
--   for name, _ in pairs(installed) do
--     if not managed[name] then
--       logger.info("Removing unused plugin: " .. name)
--       minideps.remove(name)
--       cleaned = cleaned + 1
--     end
--   end

--   if cleaned > 0 then
--     notify.info("Cleaned " .. cleaned .. " unused plugins")
--   else
--     notify.info("No unused plugins found")
--   end
-- end

-- -- Remove plugin
-- function M.remove_plugin(state, name)
--   local plugin = state.plugins[name]
--   if not plugin then
--     notify.error("Plugin not found: " .. name)
--     return false
--   end

--   local minideps = require('mini.deps')
--   minideps.remove(name)

--   state.plugins[name] = nil

--   -- Remove from loading order
--   for category, plugins in pairs(state.loading_order) do
--     for i, p in ipairs(plugins) do
--       if p.name == name then
--         table.remove(plugins, i)
--         break
--       end
--     end
--   end

--   notify.info("Removed plugin: " .. name)
--   return true
-- end

-- return M
