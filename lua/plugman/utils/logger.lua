local M = {}

local log_levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

local current_level = log_levels.INFO
local log_file = vim.fn.stdpath('cache') .. '/plugman.log'

---Setup logger
---@param level string Log level
function M.setup(level)
    current_level = log_levels[string.upper(level)] or log_levels.INFO
end

---Log message
---@param level number Log level
---@param message string Message to log
local function log(level, message)
    if level < current_level then
        return
    end

    local level_names = { 'DEBUG', 'INFO', 'WARN', 'ERROR' }
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local log_line = string.format('[%s] [%s] %s\n', timestamp, level_names[level], message)

    -- Write to file
    local file = io.open(log_file, 'a')
    if file then
        file:write(log_line)
        file:close()
    end

    -- Also print to messages if high level
    if level >= log_levels.WARN then
        print('[Plugman] ' .. message)
    end
end

function M.debug(message) log(log_levels.DEBUG, message) end

function M.info(message) log(log_levels.INFO, message) end

function M.warn(message) log(log_levels.WARN, message) end

function M.error(message) log(log_levels.ERROR, message) end

return M
