local Dashboard = require('plugman.ui.dashboard')

local M = {}

---Show UI
---@param manager PlugmanManager
function M.show(manager)
    Dashboard.show(manager)
end

return M