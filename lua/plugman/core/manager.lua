local logger = require('plugman.utils.logger')
local notify = require('plugman.utils.notify')

local M = {}

-- Add plugin to state
function M.add_plugin(state, plugin)
  state.plugins[plugin.name] = plugin
  
  -- Categorize by loading strategy
  if plugin.priority > 0 then
    table.insert(state.loading_order.priority, plugin)
    -- Sort by priority (higher first)
    table.sort(state.loading_order.priority, function(a, b)
      return a.priority > b.priority
    end)
  elseif plugin.lazy then
    table.insert(state.loading_order.lazy, plugin)
  else
    table.insert(state.loading_order.normal, plugin)
  end
  
  logger.debug("Added plugin: " .. plugin.name .. " (lazy: " .. tostring(plugin.lazy) .. ")")
end

-- Install all plugins
function M.install_all(state)
  local minideps = require('mini.deps')
  
  notify.info("Installing plugins...")
  
  local count = 0
  for name, plugin in pairs(state.plugins) do
    if not plugin.installed then
      logger.info("Installing: " .. name)
      
      local spec = plugin:get_minideps_spec()
      minideps.add(spec)
      
      plugin.installed = true
      count = count + 1
    end
  end
  
  if count > 0 then
    notify.info("Installed " .. count .. " plugins")
  else
    notify.info("All plugins already installed")
  end
end

-- Update all plugins
function M.update_all(state)
  local minideps = require('mini.deps')
  
  notify.info("Updating plugins...")
  
  for name, plugin in pairs(state.plugins) do
    if plugin.installed then
      logger.info("Updating: " .. name)
      minideps.update(plugin.name)
    end
  end
  
  notify.info("Plugin updates completed")
end

-- Clean unused plugins
function M.clean(state)
  local minideps = require('mini.deps')
  
  notify.info("Cleaning unused plugins...")
  
  -- Get list of installed plugins
  local installed = minideps.get_session()
  local managed = {}
  
  for name, _ in pairs(state.plugins) do
    managed[name] = true
  end
  
  local cleaned = 0
  for name, _ in pairs(installed) do
    if not managed[name] then
      logger.info("Removing unused plugin: " .. name)
      minideps.remove(name)
      cleaned = cleaned + 1
    end
  end
  
  if cleaned > 0 then
    notify.info("Cleaned " .. cleaned .. " unused plugins")
  else
    notify.info("No unused plugins found")
  end
end

-- Remove plugin
function M.remove_plugin(state, name)
  local plugin = state.plugins[name]
  if not plugin then
    notify.error("Plugin not found: " .. name)
    return false
  end
  
  local minideps = require('mini.deps')
  minideps.remove(name)
  
  state.plugins[name] = nil
  
  -- Remove from loading order
  for category, plugins in pairs(state.loading_order) do
    for i, p in ipairs(plugins) do
      if p.name == name then
        table.remove(plugins, i)
        break
      end
    end
  end
  
  notify.info("Removed plugin: " .. name)
  return true
end

return M