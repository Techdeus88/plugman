local M = {}

local levels = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

local level_names = {
  [1] = 'DEBUG',
  [2] = 'INFO',
  [3] = 'WARN',
  [4] = 'ERROR',
}

local config = {
  level = levels.INFO,
  file = nil,
  console = nil,
}

---Setup logger
---@param level string Log level
---@param config table|nil Log file path
function M.setup(opts)
  config.level = levels[opts.level:upper()] or levels.INFO
  config.file = opts.file
  config.console = opts.console

  if config.file then
    -- Ensure log directory exists
    local log_dir = vim.fn.fnamemodify(config.file, ':h')
    if vim.fn.isdirectory(log_dir) == 0 then
      vim.fn.mkdir(log_dir, 'p')
    end
  end
end

---Log message
---@param level number Log level
---@param message string Message
---@param ... any Additional arguments
local function log(level, message, ...)
  if level < config.level then
    return
  end

  local formatted = string.format(message, ...)
  local timestamp = os.date('%Y-%m-%d %H:%M:%S')
  local level_name = level_names[level]
  local log_line = string.format('[%s] %s: %s', timestamp, level_name, formatted)

  -- Print to console
  if config.console then
    print(log_line)
  end


  -- Write to file
  if config.file then
    local file = io.open(config.file, 'a')
    if file then
      file:write(log_line .. '\n')
      file:close()
    end
  end
end

---Debug log
---@param message string Message
---@param ... any Additional arguments
function M.debug(message, ...)
  log(levels.DEBUG, message, ...)
end

---Info log
---@param message string Message
---@param ... any Additional arguments
function M.info(message, ...)
  log(levels.INFO, message, ...)
end

---Warn log
---@param message string Message
---@param ... any Additional arguments
function M.warn(message, ...)
  log(levels.WARN, message, ...)
end

---Error log
---@param message string Message
---@param ... any Additional arguments
function M.error(message, ...)
  log(levels.ERROR, message, ...)
end

return M

-- local M = {}

-- local log_file = vim.fn.stdpath('cache') .. '/plugman.log'
-- local levels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }

-- function M.init(config)
--   M.config = vim.tbl_extend('force', {
--     level = 'INFO',
--     file = true,
--     console = false
--   }, config or {})
-- end

-- local function log(level, message)
--   if not M.config then return end

--   local level_num = levels[level]
--   local config_level_num = levels[M.config.level]

--   if level_num < config_level_num then return end

--   local timestamp = os.date('%Y-%m-%d %H:%M:%S')
--   local log_message = string.format('[%s] %s: %s', timestamp, level, message)

--   if M.config.file then
--     local file = io.open(log_file, 'a')
--     if file then
--       file:write(log_message .. '\n')
--       file:close()
--     end
--   end

--   if M.config.console then
--     print(log_message)
--   end
-- end

-- function M.debug(message) log('DEBUG', message) end
-- function M.info(message) log('INFO', message) end
-- function M.warn(message) log('WARN', message) end
-- function M.error(message) log('ERROR', message) end

-- return M
