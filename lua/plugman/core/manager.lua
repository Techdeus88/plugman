local Bootstrap = require("plugman.core.bootstrap")
local Plugin = require('plugman.core.plugin')
local Cache = require('plugman.core.cache')
local Logger = require('plugman.utils.logger')
local Notify = require('plugman.utils.notify')

---@class PlugmanManager
local Manager = {}
Manager.__index = Manager

---Create new manager instance
---@param config table Configuration
---@return PlugmanManager
function Manager.new(config)
  local self = setmetatable({}, Manager)

  self.config = config
  self.plugins = {}
  self.cache = Cache.new(config.cache_dir)
  self.loaded_plugins = {}
  self.pending_plugins = {}

  -- Bootstrap and ensure MiniDeps is installed and setup
  Bootstrap.init(config.mini_deps)
  -- Initialize MiniDeps
  require('mini.deps').setup(config.mini_deps or {})
  return self
end

---Add plugin from spec
---@param spec table|string Plugin specification
---@return PlugmanPlugin
function Manager:add_spec(spec)
  local plugin = Plugin.from_spec(spec)
  return self:add_plugin(plugin)
end

---Add plugin
---@param source string Plugin source
---@param opts table Plugin options
---@return PlugmanPlugin
function Manager:add(source, opts)
  local plugin = Plugin.new(source, opts or {})
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

  Logger.info("Installing plugin: " .. plugin.name)

  local ok, err = pcall(function()
    MiniDeps.add({
      source = plugin.source,
      depends = plugin.depends,
      hooks = {
        post_install = plugin.post_install,
        post_checkout = plugin.post_checkout,
      }
    })
  end)

  if ok then
    plugin.installed = true
    self.cache:set_plugin(plugin.name, plugin:to_cache())
    Logger.info("Installed plugin: " .. plugin.name)
    Notify.info("Installed: " .. plugin.name)
    return true
  else
    Logger.error("Failed to install plugin: " .. plugin.name .. " - " .. tostring(err))
    Notify.error("Failed to install: " .. plugin.name)
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

  -- Install if not installed
  if not plugin.installed then
    if not self:install(plugin) then
      return false
    end
  end

  Logger.info("Loading plugin: " .. plugin.name)

  -- Run init hook
  if plugin.init then
    local ok, err = pcall(plugin.init)
    if not ok then
      Logger.error("Plugin init failed: " .. plugin.name .. " - " .. tostring(err))
    end
  end

  -- Load plugin files
  local ok, err = pcall(MiniDeps.now, plugin.source)
  if not ok then
    Logger.error("Failed to load plugin: " .. plugin.name .. " - " .. tostring(err))
    return false
  end

  -- Setup plugin
  if plugin.config then
    local config_ok, config_err = pcall(plugin.config)
    if not config_ok then
      Logger.error("Plugin config failed: " .. plugin.name .. " - " .. tostring(config_err))
    end
  end

  -- Setup keymaps
  if plugin.keys then
    self:setup_keymaps(plugin)
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

  Logger.info("Loaded plugin: " .. plugin.name)
  return true
end

---Setup keymaps for plugin
---@param plugin PlugmanPlugin
function Manager:setup_keymaps(plugin)
  for _, keymap in ipairs(plugin.keys) do
    local mode = keymap.mode or keymap[1] or 'n'
    local lhs = keymap.lhs or keymap[2]
    local rhs = keymap.rhs or keymap[3]
    local opts = keymap.opts or {}

    if keymap.desc then
      opts.desc = keymap.desc
    end

    vim.keymap.set(mode, lhs, rhs, opts)
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

return Manager



-- local logger = require('plugman.utils.logger')
-- local notify = require('plugman.utils.notify')

-- local M = {}

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
