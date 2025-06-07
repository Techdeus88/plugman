local M = {}

local logger = require("plugman.utils.logger")

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

---Filter plugins based on a condition or attribute
---@param plugins PlugmanPlugin[] Array of plugins to filter
---@param condition string|function Condition to filter by. Can be:
---   - A string representing an attribute name (e.g., "enabled", "lazy")
---   - A function that takes a plugin and returns a boolean
---@param value any|nil Optional value to compare against if condition is a string
---@return PlugmanPlugin[] Filtered array of plugins
function M.filter_plugins(plugins, condition, value)
    if type(plugins) ~= "table" then
        return {}
    end

    local filtered = {}
    for name, plugin in pairs(plugins) do
        local matches = false

        if type(condition) == "function" then
            matches = condition(plugin)
        elseif type(condition) == "string" then
            if value ~= nil then
                matches = plugin[condition] == value
            else
                matches = plugin[condition] ~= nil and plugin[condition] ~= false
            end
        end

        if matches then
            filtered[name] = plugin
        end
    end

    return filtered
end

---Filter plugins by multiple conditions
---@param plugins PlugmanPlugin[] Array of plugins to filter
---@param conditions table<string, any> Table of conditions where key is attribute and value is expected value
---@return PlugmanPlugin[] Filtered array of plugins
function M.filter_plugins_all(plugins, conditions)
    if type(plugins) ~= "table" or type(conditions) ~= "table" then
        return {}
    end

    local filtered = plugins
    for attr, value in pairs(conditions) do
        filtered = M.filter_plugins(filtered, attr, value)
    end

    return filtered
end

-- Deep merge function that preserves structure and handles nested tables
    function M.deep_merge(default_tbl, override_tbl)
        local result = vim.deepcopy(default_tbl)
        
        -- Function to recursively merge tables
        local function merge(target, source)
            for k, v in pairs(source) do
                if type(v) == "table" and type(target[k]) == "table" then
                    -- Recursively merge if both values are tables
                    merge(target[k], v)
                else
                    -- Override with source value
                    target[k] = v
                end
            end
            return target
        end
        return merge(result, override_tbl or {})
    end


return M