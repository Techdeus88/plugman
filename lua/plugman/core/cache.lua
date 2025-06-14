local Logger = require('plugman.utils.logger')

---@class PlugmanCache
---@field cache_dir string
---@field cache_file string
local Cache = {}
Cache.__index = Cache

---Create new cache
---@param config table Cache config table
---@return PlugmanCache
function Cache.new(config)
  local self = setmetatable({}, Cache)

  self.cache_dir = config.cache_dir
  self.cache_file = config.cache_dir .. '/plugman.json'
  self.data = {}

  self:ensure_cache_dir()
  self:load()

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
  -- Create a copy of data that can be serialized
  local serializable_data = filter_serializable(self.data)

  local ok, json = pcall(vim.json.encode, serializable_data)
  if ok then
    vim.fn.writefile({ json }, self.cache_file)
    Logger.debug("Cache saved successfully")
  else
    Logger.error("Failed to encode cache data")
  end
end

---Set plugin data
---@param name string Plugin name
---@param data table Plugin data
function Cache:set_plugin(name, data)
  if not self.data.plugins then
    self.data.plugins = {}
  end

  self.data.plugins[name] = data
  self:save()
end

---Get plugin data
---@param name string Plugin name
---@return table|nil Plugin data
function Cache:get_plugin(name)
  if not self.data.plugins then
    return nil
  end

  return self.data.plugins[name]
end

---Remove plugin data
---@param name string Plugin name
function Cache:remove_plugin(name)
  if self.data.plugins then
    self.data.plugins[name] = nil
    self:save()
  end
end

---Clear cache
function Cache:clear()
  self.data = {}
  self:save()
  Logger.info("Cache cleared")
end

---Get cache stats
---@return table Cache statistics
function Cache:stats()
  local plugin_count = 0
  if self.data.plugins then
    plugin_count = vim.tbl_count(self.data.plugins)
  end

  return {
    plugin_count = plugin_count,
    cache_file = self.cache_file,
    size = vim.fn.getfsize(self.cache_file),
  }
end

return Cache
