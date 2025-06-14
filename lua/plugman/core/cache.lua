local Logger = require('plugman.utils.logger')

---@class PlugmanCache
---@field cache_dir string
---@field cache_file string
---@field data table
---@field dirty boolean
local Cache = {}
Cache.__index = Cache

---Create new cache
---@param config table Configuration
---@return PlugmanCache
function Cache.new(config)
  local self = setmetatable({}, Cache)

  self.cache_dir = config.paths.cache_dir
  self.cache_file = config.paths.cache_dir .. '/plugman.json'
  self.data = {}
  self.dirty = false
  self.last_save = 0
  self.save_interval = config.performance.cache_ttl * 1000

  self:ensure_cache_dir()
  self:load()

  -- Setup auto-save
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if self.dirty then
        self:save()
      end
    end,
  })

  return self
end

---Ensure cache directory exists
function Cache:ensure_cache_dir()
  if vim.fn.isdirectory(self.cache_dir) == 0 then
    vim.fn.mkdir(self.cache_dir, 'p')
  end
end

---Load cache from file
function Cache:load()
  if vim.fn.filereadable(self.cache_file) == 1 then
    local content = vim.fn.readfile(self.cache_file)
    if #content > 0 then
      local ok, data = pcall(vim.json.decode, table.concat(content, '\n'))
      if ok then
        self.data = data
        Logger.debug("Cache loaded successfully")
      else
        Logger.warn("Failed to parse cache file, starting fresh")
        self.data = {}
      end
    end
  end
end

---Filter out non-serializable data recursively
---@param data any Data to filter
---@return any Filtered data
local function filter_serializable(data)
  if type(data) ~= 'table' then
    return data
  end

  local result = {}
  for k, v in pairs(data) do
    if type(v) == 'function' then
      -- Skip functions
      goto continue
    elseif type(v) == 'table' then
      result[k] = filter_serializable(v)
    else
      result[k] = v
    end
    ::continue::
  end
  return result
end

---Save cache to file
function Cache:save()
  if not self.dirty then
    return
  end

  local filtered_data = filter_serializable(self.data)
  local json = vim.json.encode(filtered_data)
  vim.fn.writefile(vim.split(json, '\n'), self.cache_file)
  self.dirty = false
  self.last_save = vim.loop.now()
  Logger.debug("Cache saved successfully")
end

---Schedule a save if needed
function Cache:schedule_save()
  if not self.dirty then
    return
  end

  local now = vim.loop.now()
  if now - self.last_save >= self.save_interval then
    self:save()
  else
    vim.defer_fn(function()
      self:save()
    end, self.save_interval - (now - self.last_save))
  end
end

---Set plugin data
---@param name string Plugin name
---@param data table Plugin data
function Cache:set_plugin(name, data)
  self.data[name] = data
  self.dirty = true
  self:schedule_save()
end

---Get plugin data
---@param name string Plugin name
---@return table|nil Plugin data
function Cache:get_plugin(name)
  return self.data[name]
end

---Remove plugin data
---@param name string Plugin name
function Cache:remove_plugin(name)
  self.data[name] = nil
  self.dirty = true
  self:schedule_save()
end

---Get cache statistics
---@return table Stats
function Cache:stats()
  local size = 0
  local count = 0

  for name, data in pairs(self.data) do
    count = count + 1
    size = size + #vim.json.encode(data)
  end

  return {
    plugin_count = count,
    size = size
  }
end

return Cache
