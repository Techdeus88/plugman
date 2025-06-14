local M = {}

-- Core modules
local Manager = require('plugman.core.manager')
local Messages = require('plugman.utils.message_handler')
local Loader = require('plugman.core.loader')
local Logger = require('plugman.utils.logger')
local Notify = require('plugman.utils.notify')
local UI = require('plugman.ui')
local Config = require('plugman.config')
local Events = require('plugman.core.events')
local Cache = require('plugman.core.cache')
local Health = require('plugman.health')

-- Global state
M.manager = nil
M.loader = nil
M.config = nil

-- Cache for plugin discovry
local discovery_cache = {
  timestamp = 0,
  specs = {},
  modules = {}
}

---Discover modules in the modules directory
---@return table List of discovered module specifications
local function _discover_modules()
  local modules_dir = Config.paths.modules_dir
  if not vim.fn.isdirectory(modules_dir) then
    return {}
  end

  local specs = {}
  local files = vim.fn.glob(modules_dir .. '/**/*.lua', true, true)

  for _, file in ipairs(files) do
    local module_name = file:match(modules_dir .. '/(.+)%.lua$')
    if module_name then
      module_name = module_name:gsub('/', '.')
      table.insert(specs, {
        name = module_name,
        type = 'module',
        path = file,
        priority = 1 -- Modules are loaded first
      })
    end
  end

  return specs
end

---Discover plugin specifications in the plugins directory
---@return table List of discovered plugin specifications
local function _discover_plugin_specs()
  local specs = {}
  local plugins_dirs = Config.paths.plugins_dir

  for _, dir in ipairs(plugins_dirs) do
    if vim.fn.isdirectory(dir) then
      -- Find all Lua files in the directory
      local files = vim.fn.glob(dir .. '/**/*.lua', true, true)

      for _, file in ipairs(files) do
        local spec = dofile(file)
        if spec then
          -- Handle both single and multi-spec files
          if spec.name then
            -- Single spec file
            spec.path = file
            table.insert(specs, spec)
          elseif type(spec) == 'table' then
            -- Multi-spec file
            for _, s in ipairs(spec) do
              if s.name then
                s.path = file
                table.insert(specs, s)
              end
            end
          end
        end
      end
    end
  end

  return specs
end

---Discover all plugins and modules
---@return table List of all discovered specifications
local function _discover_plugins()
  -- Check cache first
  local now = os.time()
  if now - discovery_cache.timestamp < Config.performance.cache_ttl then
    return discovery_cache.specs
  end

  -- Discover modules and plugins
  local module_specs = _discover_modules()
  local plugin_specs = _discover_plugin_specs()

  -- Combine and cache results
  local all_specs = vim.list_extend(module_specs, plugin_specs)
  discovery_cache = {
    timestamp = now,
    specs = all_specs,
    modules = module_specs
  }

  return all_specs
end

---Initialize Plugman
---@param opts table Configuration options
function M.setup(opts)
  -- Load configuration
  M.config = Config.setup(opts)

  -- Initialize components
  Logger.setup(M.config.logging)
  Notify.setup(M.config.notify)
  Messages.init(M.config.messages)
  M.manager = Manager.new(M.config)
  M.loader = Loader.new(M.manager, M.config)
  M.events = Events.new(M.loader)
  M.cache = Cache.new(M.config)

  -- Discover and load plugins
  local specs = _discover_plugins()
  for _, spec in ipairs(specs) do
    M.manager:add_spec(spec)
  end

  -- Load startup plugins
  M.loader:load_startup_plugins()

  -- Run initial health check
  local health_report = Health.check(M.manager)
  if health_report.status ~= 'ok' then
    Logger.warn("Initial health check found issues: " .. Health.format_report(health_report))
  end

  Logger.info("Plugman initialized successfully")
  Notify.info("Plugman ready!")
end

---Add a plugin
---@param source string Plugin source (GitHub repo, local path, etc.)
---@param opts table Plugin options
function M.add(source, opts)
  if not M.manager then
    error("Plugman not initialized. Call setup() first.")
  end

  return M.manager:add(source, opts, "plugin")
end

---Remove a plugin
---@param name string Plugin name
function M.remove(name)
  if not M.manager then
    error("Plugman not initialized. Call setup() first.")
  end

  return M.manager:remove(name)
end

---Update plugins
---@param names table|nil Specific plugin names to update
function M.update(names)
  if not M.manager then
    error("Plugman not initialized. Call setup() first.")
  end

  return M.manager:update(names)
end

---Show UI
function M.show()
  if not M.manager then
    error("Plugman not initialized. Call setup() first.")
  end

  UI.show(M.manager)
end

---Get plugin status
---@param name string Plugin name
---@return table|nil Plugin status
function M.status(name)
  if not M.manager then
    return nil
  end

  return M.manager:status(name)
end

---Get the plugin manager instance
---@return table Plugin manager instance
function M.get_manager()
  return M.manager
end

---Get the plugin loader instance
---@return table Plugin loader instance
function M.get_loader()
  return M.loader
end

---Get the event system instance
---@return table Event system instance
function M.get_events()
  return M.events
end

---Get the cache instance
---@return table Cache instance
function M.get_cache()
  return Cache
end

return M
