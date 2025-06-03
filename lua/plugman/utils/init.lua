local M = {}

local logger = require("lua.plugman.utils.logger")




function M.get_timing_function(plugin, phase)
    if phase.timing == "now" then
      return MiniDeps.now
    end
    if phase.timing == "later" then
      return MiniDeps.later
    end
    return (plugin.lazy ~= nil and plugin.lazy) and MiniDeps.later or MiniDeps.now
  end


---Safely call functions that do not use require
---@param fn function
---@param ... any
---@return any
function M.safe_pcall(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
      vim.notify(string.format("Error: %s", result), vim.log.levels.ERROR)
      return nil
    end
    return result
  end

---Convert value to boolean
---@param value any Value to convert
---@return boolean
function M.to_boolean(value)
    if type(value) == 'boolean' then
        return value
    end
    return not not value
end

---Convert table values to boolean
---@param tbl table Table to convert
---@return table
function M.table_to_boolean(tbl)
    local result = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            result[k] = M.table_to_boolean(v)
        else
            result[k] = M.to_boolean(v)
        end
    end
    return result
end

---Validate if string is a valid GitHub URL
---@param url string URL to validate
---@return boolean
function M.is_valid_github_url(url)
    if not url or type(url) ~= 'string' then
        return false
    end

    -- Basic GitHub URL patterns
    local patterns = {
        '^https?://github%.com/[%w-]+/[%w-%.]+/?$',  -- https://github.com/user/repo
        '^github%.com/[%w-]+/[%w-%.]+/?$',           -- github.com/user/repo
        '^[%w-]+/[%w-%.]+$'                          -- user/repo
    }

    -- Debug logging
    logger.debug(string.format('Validating GitHub URL: %s', url))

    for _, pattern in ipairs(patterns) do
        if url:match(pattern) then
            logger.debug(string.format('URL %s matched pattern: %s', url, pattern))
            return true
        end
    end

    logger.debug(string.format('URL %s did not match any patterns', url))
    return false
end

---Extract GitHub repository information
---@param url string GitHub URL
---@return string|nil, string|nil username and repository name
function M.extract_github_info(url)
    -- Try full URL pattern first
    local username, repo = url:match('github%.com/([%w-]+)/([%w-%.]+)')
    if not username then
        -- Try short format (user/repo)
        username, repo = url:match('([%w-]+)/([%w-%.]+)')
    end

    -- Debug logging
    logger.debug(string.format('Extracted GitHub info from %s: username=%s, repo=%s', url, username or 'nil', repo or 'nil'))
    
    return username, repo
end

---Normalize GitHub URL
---@param url string GitHub URL
---@return string Normalized URL
function M.normalize_github_url(url)
    if url:match('^https?://') then
        return url
    end
    return 'https://github.com/' .. url
end


return M