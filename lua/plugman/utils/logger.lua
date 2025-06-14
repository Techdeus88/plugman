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
  log_file = nil,
}

---Setup logger
---@param opts table Log file path
function M.setup(opts)
  config.level = levels[opts.level:upper()] or levels.INFO
  config.file = opts.file
  config.console = opts.console

  if config.file then
    -- Ensure log directory exists
    local log_dir = vim.fn.fnamemodify(config.log_file, ':h')
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
  local opts = ... ~= nil and ... or {}

  local formatted = string.format("%s %s", message, table.concat(opts, "-"))
  local timestamp = os.date('%Y-%m-%d %H:%M:%S')
  local level_name = level_names[level]
  local log_line = string.format('[%s] %s: %s', timestamp, level_name, formatted)

  -- Print to console
  if config.console then
    print(log_line)
  end


  -- Write to file
  if config.file ~= nil then
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
function M.error(message, ...) log(levels.ERROR, message, ...)
end

return M
