local M = {}

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
    -- Basic GitHub URL patterns
    local patterns = {
        '^https?://github%.com/[%w-]+/[%w-]+/?$', -- https://github.com/user/repo
        '^github%.com/[%w-]+/[%w-]+/?$',          -- github.com/user/repo
        '^[%w-]+/[%w-]+$'                         -- user/repo
    }

    for _, pattern in ipairs(patterns) do
        if url:match(pattern) then
            return true
        end
    end
    return false
end

---Extract GitHub repository information
---@param url string GitHub URL
---@return string|nil, string|nil username and repository name
function M.extract_github_info(url)
    local username, repo = url:match('github%.com/([%w-]+)/([%w-]+)')
    if not username then
        username, repo = url:match('([%w-]+)/([%w-]+)')
    end
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