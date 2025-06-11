local M = {}

local log_file = vim.fn.stdpath('cache') .. '/plugman.log'
local levels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }

function M.init(config)
  M.config = vim.tbl_extend('force', {
    level = 'INFO',
    file = true,
    console = false
  }, config or {})
end

local function log(level, message)
  if not M.config then return end
  
  local level_num = levels[level]
  local config_level_num = levels[M.config.level]
  
  if level_num < config_level_num then return end
  
  local timestamp = os.date('%Y-%m-%d %H:%M:%S')
  local log_message = string.format('[%s] %s: %s', timestamp, level, message)
  
  if M.config.file then
    local file = io.open(log_file, 'a')
    if file then
      file:write(log_message .. '\n')
      file:close()
    end
  end
  
  if M.config.console then
    print(log_message)
  end
end

function M.debug(message) log('DEBUG', message) end
function M.info(message) log('INFO', message) end
function M.warn(message) log('WARN', message) end
function M.error(message) log('ERROR', message) end

return M