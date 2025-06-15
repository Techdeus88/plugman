-- This module wraps MiniDeps functionality
local M = {}
local Logger = require('plugman.utils.logger')

-- Constants
local path_package = vim.fn.stdpath("data") .. "/site/"
local MINIDEPS_REPO = "https://github.com/echasnovski/mini.deps"
local MINIDEPS_PATH = path_package .. "pack/deps/start/mini.deps"
local messages = require('plugman.utils.message_handler')

-- MiniDeps operation types
local OPERATIONS = {
  INSTALL = 'install',
  UPDATE = 'update',
  REMOVE = 'remove',
  CLEAN = 'clean'
}

-- Operation status
local STATUS = {
  PENDING = 'pending',
  RUNNING = 'running',
  COMPLETED = 'completed',
  FAILED = 'failed'
}

-- Operation tracking
local operations = {}

-- Event callbacks
local event_handlers = {
  on_operation_start = {},
  on_operation_progress = {},
  on_operation_complete = {},
  on_operation_error = {}
}

-- Register event handler
function M.on(event, callback)
  if not event_handlers[event] then
    error('Invalid event: ' .. event)
  end
  table.insert(event_handlers[event], callback)
end

-- Trigger event
local function trigger_event(event, ...)
  for _, handler in ipairs(event_handlers[event]) do
    handler(...)
  end
end

-- Track operation
local function track_operation(name, operation_type)
  local op = {
    name = name,
    type = operation_type,
    status = STATUS.PENDING,
    start_time = vim.loop.now(),
    progress = 0,
    message = ''
  }
  operations[name] = op
  trigger_event('on_operation_start', op)
  return op
end

-- Update operation status
local function update_operation(name, status, progress, message)
  local op = operations[name]
  if op then
    op.status = status
    op.progress = progress or op.progress
    op.message = message or op.message
    op.end_time = vim.loop.now()
    
    if status == STATUS.COMPLETED then
      trigger_event('on_operation_complete', op)
    elseif status == STATUS.FAILED then
      trigger_event('on_operation_error', op)
    else
      trigger_event('on_operation_progress', op)
    end
  end
end

local function install_minideps()
    local function is_minideps_installed()
        -- return vim.fn.isdirectory(MINIDEPS_PATH) == 1
        return vim.uv.fs_stat(MINIDEPS_PATH)
    end
    local install = function()
        local success = pcall(function()
            -- Create the directory if it doesn't exist
            vim.fn.mkdir(path_package .. "pack/deps/start", "p")

            -- Clone the repository
            vim.fn.system({
                "git",
                "clone",
                "--depth", "1",
                MINIDEPS_REPO,
                MINIDEPS_PATH
            })
        end)
        return success
    end

    -- Installs MiniDeps if it is unavailable
    if not is_minideps_installed() then
        messages.minideps('INFO', "Installing MiniDeps...")
        local success = install()
        if not success then
            messages.minideps('ERROR', "Failed to install MiniDeps")
            return false
        end
        -- Add MiniDeps to runtime path
        vim.cmd("packadd mini.deps | helptags ALL")
        messages.minideps('SUCCESS', "MiniDeps installed successfully")
        return true
    end
    return true
end

-- Initialize MiniDeps if not already loaded
function M.ensure_minideps()
    local minideps_path = vim.fn.stdpath('data') .. '/site/pack/deps/start/mini.deps'
    if not vim.loop.fs_stat(minideps_path) then
        messages.minideps('INFO', "Installing MiniDeps...")
        local success = pcall(function()
            -- Create the directory if it doesn't exist
            vim.fn.mkdir(vim.fn.stdpath("data") .. "/site/pack/deps/start", "p")

            -- Clone the repository
            vim.fn.system({
                "git",
                "clone",
                "--depth", "1",
                MINIDEPS_REPO,
                MINIDEPS_PATH
            })
        end)
        if success then
            vim.cmd("packadd mini.deps | helptags ALL")
            messages.minideps('SUCCESS', "MiniDeps installed successfully")
        else
            messages.minideps('ERROR', "Failed to install MiniDeps")
        end
    end
end

---Setup MiniDeps integration
---@param opts? table|nil MiniDeps options
function M.init(opts)
    -- Install MiniDeps: only if unavailable
    if not install_minideps() then
        return false
    end
    -- Ensure MiniDeps is available
    local has_minideps, MiniDeps = pcall(require, 'mini.deps')

    if not has_minideps then
        messages.minideps('ERROR', 'MiniDeps not found. Please install mini.deps first.')
        return false
    end

    -- Setup MiniDeps with user options
    MiniDeps.setup(opts)

    -- Make MiniDeps functions available globally
    _G.MiniDeps = MiniDeps
    _G.Add = MiniDeps.add
    _G.Now = MiniDeps.now
    _G.Later = MiniDeps.later

    M.MiniDeps = MiniDeps
    messages.minideps('SUCCESS', 'MiniDeps integration initialized')
    return true
end

---Add plugin using MiniDeps
---@param plugin_register PlugmanRegister plugin
---@return boolean Success status
function M.deps_add(plugin_register)
    if not M.MiniDeps then
        messages.minideps('ERROR', 'MiniDeps not initialized')
        return false
    end

    local success, err = pcall(function()
        M.MiniDeps.add(plugin_register)
    end)

    if not success then
        messages.minideps('ERROR', string.format('Failed to add %s: %s', plugin_register.source, err))
        return false
    end

    return true
end

---Remove plugin using MiniDeps
---@param name string Plugin name
---@return boolean Success status
function M.remove_plugin(name)
    if not M.MiniDeps then
        messages.minideps('ERROR', 'MiniDeps not initialized')
        return false
    end

    -- MiniDeps doesn't have a direct remove function
    -- This would need to be implemented based on MiniDeps API
    local success, err = pcall(function()
        M.MiniDeps.clean(name)
    end)

    if not success then
        messages.minideps('ERROR', string.format('Failed to remove %s: %s', name, err))
        return false
    else
        messages.minideps('SUCCESS', string.format('Successfully removed: %s', name))
        return true
    end
    -- logger.warn('Plugin removal not yet implemented in MiniDeps')
end

---Update plugins using MiniDeps
---@param name? string Plugin name (nil for all)
function M.update_plugin(name)
    if not M.MiniDeps then
        messages.minideps('ERROR', 'MiniDeps not initialized')
        return false
    end

    if name then
        -- Update specific plugin
        messages.minideps('WARN', 'MiniDeps cannot update individual plugins')
        return false
        -- M..update(name)
    else
        -- Update all plugins
        local success, err = pcall(function()
            M.MiniDeps.update()
        end)
        if not success then
            messages.minideps('ERROR', string.format('Failed to update %s: %s', name, err))
            return false
        else
            messages.minideps('SUCCESS', string.format('Successfully updated plugin: %s', name))
            return true
        end
    end
end

-- Wrap MiniDeps operations
function M.add(plugin_spec)
  local name = plugin_spec.source:match("([^/]+)%.git$") or plugin_spec.source
  local op = track_operation(name, OPERATIONS.INSTALL)
  
  -- Create progress callback
  local progress_callback = function(progress, message)
    update_operation(name, STATUS.RUNNING, progress, message)
  end
  
  -- Wrap the plugin spec with our progress callback
  plugin_spec.progress = progress_callback
  
  -- Execute MiniDeps operation
  local ok, err = pcall(function()
    M.MiniDeps.add(plugin_spec)
  end)
  
  if ok then
    update_operation(name, STATUS.COMPLETED, 100, "Installation completed")
  else
    update_operation(name, STATUS.FAILED, 0, "Installation failed: " .. tostring(err))
  end
  
  return ok, err
end

function M.update(plugin_name)
  local op = track_operation(plugin_name, OPERATIONS.UPDATE)
  
  local progress_callback = function(progress, message)
    update_operation(plugin_name, STATUS.RUNNING, progress, message)
  end
  
  local ok, err = pcall(function()
    M.MiniDeps.update(plugin_name, { progress = progress_callback })
  end)
  
  if ok then
    update_operation(plugin_name, STATUS.COMPLETED, 100, "Update completed")
  else
    update_operation(plugin_name, STATUS.FAILED, 0, "Update failed: " .. tostring(err))
  end
  
  return ok, err
end

function M.remove(plugin_name)
  local op = track_operation(plugin_name, OPERATIONS.REMOVE)
  
  local ok, err = pcall(function()
    M.MiniDeps.clean(plugin_name)
  end)
  
  if ok then
    update_operation(plugin_name, STATUS.COMPLETED, 100, "Removal completed")
  else
    update_operation(plugin_name, STATUS.FAILED, 0, "Removal failed: " .. tostring(err))
  end
  
  return ok, err
end

-- Get current operations
function M.get_operations()
  return operations
end

-- Get operation status
function M.get_operation_status(name)
  return operations[name]
end

return M
