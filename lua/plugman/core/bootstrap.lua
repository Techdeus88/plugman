-- This module wraps MiniDeps functionality
local M = {}

-- Constants
local MINIDEPS_REPO = "https://github.com/echasnovski/mini.deps"
local path_package = vim.fn.stdpath("data") .. "/site/"
local MINIDEPS_PATH = path_package .. "pack/deps/start/mini.deps"
local messages = require('plugman.utils.message_handler')

local function install_minideps()
    local function is_minideps_installed()
        -- return vim.fn.isdirectory(MINIDEPS_PATH) == 1
        return vim.uv.fs_stat(MINIDEPS_PATH)
    end
    local install = function()
        local success = pcall(function()
            print('installing')
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
    Add, Now, Later = MiniDeps.add, MiniDeps.now, MiniDeps.later

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

return M
