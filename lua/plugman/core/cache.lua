local M = {}

local cache_file = vim.fn.stdpath('cache') .. '/plugman_cache.json'

function M.init(config)
  M.config = config or { enabled = true }
  M.cache = M.load() or {}
end

function M.load()
  if not M.config.enabled then return {} end
  
  local file = io.open(cache_file, 'r')
  if not file then return {} end
  
  local content = file:read('*all')
  file:close()
  
  local ok, data = pcall(vim.json.decode, content)
  return ok and data or {}
end

function M.save()
  if not M.config.enabled then return end
  
  local file = io.open(cache_file, 'w')
  if not file then return end
  
  local content = vim.json.encode(M.cache)
  file:write(content)
  file:close()
end

function M.get(key)
  return M.cache[key]
end

function M.set(key, value)
  M.cache[key] = value
  M.save()
end

function M.clear()
  M.cache = {}
  M.save()
end

return M