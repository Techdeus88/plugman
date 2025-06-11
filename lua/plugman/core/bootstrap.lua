-- This module wraps MiniDeps functionality
local M = {}

-- Constants
local MINIDEPS_REPO = "https://github.com/echasnovski/mini.deps"
local MINIDEPS_PATH = vim.fn.stdpath("data") .. "/site/pack/deps/start/mini.deps"

local logger = require('plugman.utils.logger')

local function install_minideps()
    local function is_minideps_installed()
        return vim.fn.isdirectory(MINIDEPS_PATH) == 1
    end
    local install = function()
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
        return success
    end

    -- Installs MiniDeps if it is unavailable
    if not is_minideps_installed() then
        vim.notify("Installing MiniDeps...")
        local success = install()
        if not success then
            logger.error("Failed to install MiniDeps")
        end
        -- Add MiniDeps to runtime path
        vim.cmd("packadd mini.deps | helptags ALL")
        vim.cmd.echo('"Installed `mini.deps`" | redraw')
    end
end
-- Initialize MiniDeps if not already loaded
function M.ensure_minideps()
    local minideps_path = vim.fn.stdpath('data') .. '/site/pack/deps/start/mini.deps'
    if not vim.loop.fs_stat(minideps_path) then
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
    end
    vim.cmd("packadd mini.deps | helptags ALL")
    vim.cmd.echo('"Installed `mini.deps`" | redraw')
end

---Setup MiniDeps integration
---@param opts? table|nil MiniDeps options
function M.init(opts)
    -- Install MiniDeps: only if unavailable
    install_minideps()
    -- Ensure MiniDeps is available
    local has_minideps, MiniDeps = pcall(require, 'mini.deps')

    if not has_minideps then
        logger.error('MiniDeps not found. Please install mini.deps first.')
        return false
    end

    -- Setup MiniDeps with user options
    MiniDeps.setup(opts)

    M.MiniDeps = MiniDeps
    M.now = MiniDeps.now
    M.later = MiniDeps.later
    logger.info('MiniDeps integration initialized')
    return true
end

---Add plugin using MiniDeps
---@param plugin_register PlugmanRegister plugin
---@return boolean Success status
function M.deps_add(plugin_register)
    if not M.MiniDeps then
        logger.error('MiniDeps not initialized')
        return false
    end

    local success, err = pcall(function()
        M.MiniDeps.add(plugin_register)
    end)

    if not success then
        logger.error(string.format('MiniDeps failed to add %s: %s', plugin_register.source, err))
        return false
    end

    return true
end

---Remove plugin using MiniDeps
---@param name string Plugin name
---@return boolean Success status
function M.remove_plugin(name)
    if not M.MiniDeps then
        logger.error('MiniDeps not initialized')
        return false
    end

    -- MiniDeps doesn't have a direct remove function
    -- This would need to be implemented based on MiniDeps API
    local success, err = pcall(function()
        M.MiniDeps.clean(name)
    end)

    if not success then
        logger.error(string.format('MiniDeps failed to remove %s: %s', name, err))
        return false
    else
        logger.info(string.format('MiniDeps successfully removed: %s', name))
        return true
    end
    -- logger.warn('Plugin removal not yet implemented in MiniDeps')
end

---Update plugins using MiniDeps
---@param name? string Plugin name (nil for all)
function M.update_plugin(name)
    if not M.MiniDeps then
        logger.error('MiniDeps not initialized')
        return false
    end

    if name then
        -- Update specific plugin
        logger.warn('MiniDeps cannot update individual plugins')
        return false
        -- M..update(name)
    else
        -- Update all plugins
        local success, err = pcall(function()
            M.MiniDeps.update()
        end)
        if not success then
            logger.error(string.format('MiniDeps failed to update %s: %s', name, err))
            return false
        else
            logger.info(string.format('MiniDeps successfully updated plugin: %s', name))
            return true
        end
    end
end

return M
