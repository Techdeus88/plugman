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

return M