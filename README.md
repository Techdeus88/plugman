# Neovim Plugin Manager

A lightweight and efficient plugin manager for Neovim, built on top of MiniDeps.

## Features

- **Efficient Plugin Management**: Uses MiniDeps for fast and reliable plugin management
- **Lazy Loading**: Support for lazy loading plugins based on events, commands, and filetypes
- **Event System**: Comprehensive event handling system for plugin lifecycle management
- **Logging**: Detailed logging with configurable levels and profiling support
- **Caching**: Built-in caching for improved performance
- **Error Handling**: Robust error handling and recovery mechanisms
- **Self-Contained**: Automatically installs its only dependency (MiniDeps)

Key Features Implemented

Lazy Loading: Event, command, filetype, and key-based lazy loading
Caching: Automatic caching for faster subsequent loads
Priority Loading: Load plugins in specified order
Dependency Management: Automatic dependency resolution
UI: Simple dashboard showing plugin status
Logging: Comprehensive logging system
Notifications: User-friendly notifications for state changes
Health Checks: Built-in health checking
Keymaps: Automatic keymap setup for plugins
Hooks: Init and post-load hooks
Module Support: Load plugins from module files
Commands: User commands for management

This implementation provides a robust, lightweight plugin manager that extends MiniDeps with modern features while maintaining optimal performance and simplicity.

## Installation
-- Clone 'plugman.nvim' manually!

Plugman, at its core, is a wrapper over MiniDeps adding much desired features such as lazy loading, an intuitive UI to track, monitor plugins, and optimal logging, caching and health checks.

MiniDeps paths deteermine where the optional plugins are stored
---------------------------------------------------------------
local path_package = vim.fn.stdpath('data') .. '/site/'
local mini_path = path_package .. 'pack/deps/start/mini.nvim'
local plugman_path = path_package .. 'pack/deps/start/plugman.nvim'

if not vim.loop.fs_stat(plugman_path) then
  vim.cmd('echo "Installing `plugman.nvim`" | redraw')
  local clone_cmd = {
    'git', 'clone', '--filter=blob:none',
    'https://github.com/techdeus88/plugman.nvim', plugman_path
  }
  vim.fn.system(clone_cmd)
  vim.cmd('packadd plugman.nvim | helptags ALL')
  vim.cmd('echo "Installed `plugman.nvim`" | redraw')
end

The engine, MiniDeps is already included in your Neovim configuration. MiniDeps will install if it's not already present.

## Usage

### Basic Setup

```lua
-- Initialize the plugin manager
require("modules.plugin_manager").setup({
    -- General settings
    auto_clean = true,
    log_level = "info",
    
    -- Loading settings
    lazy_load = true,
    event_load = true,
    cmd_load = true,
    ft_load = true,
    
    -- Performance settings
    n_threads = 10,
    timeout = 30000,
    retry = 2,
    
    -- Cache settings
    cache_enabled = true,
    cache_path = vim.fn.stdpath("cache") .. "/mini-deps",
    cache_ttl = 86400,
    
    -- UI settings
    show_status = true,
    status_style = "minimal",
    
    -- Debug settings
    debug = false,
    profile = false
})
```
### Install Plugman

### Easy setup default configuration

-- In your init.lua
require('plugman').setup({
    log_level = 'info',
    cache = { enabled = true },
    notify = { use_nvim_notify = true }
})

### Adding Plugins

```lua
local plugin_manager = require("modules.plugin_manager")

-- Add a plugin
plugin_manager.add_plugin({
    name = "plugin-name",
    url = "https://github.com/user/plugin",
    lazy = true,  -- Optional: lazy load the plugin
    events = {    -- Optional: event-based loading
        BUF_ENTER = function()
            -- Plugin initialization code
        end
    }
})
```

### Loading Plugins

```lua
-- Load all plugins
plugin_manager.load_plugins()

-- Reload a specific plugin
plugin_manager.reload_plugin("plugin-name")

-- Remove a plugin
plugin_manager.remove_plugin("plugin-name")
```

### Event Handling

```lua
-- Register an event handler
plugin_manager.register_plugin_event("plugin-name", "BUF_ENTER", function()
    -- Event handling code
end)

-- Unregister an event handler
plugin_manager.unregister_plugin_event("plugin-name", "BUF_ENTER")
```

### Status and Information

```lua
-- Get plugin status
local status = plugin_manager.get_plugin_status("plugin-name")

-- Get all plugins
local plugins = plugin_manager.get_all_plugins()

-- Get loaded plugins
local loaded = plugin_manager.get_loaded_plugins()

-- Get failed plugins
local failed = plugin_manager.get_failed_plugins()

-- Get pending plugins
local pending = plugin_manager.get_pending_plugins()
```

### Debug and Maintenance

```lua
-- Clear plugin cache
plugin_manager.clear_cache()

-- Get logs
local logs = plugin_manager.get_logs()

-- Clear logs
plugin_manager.clear_logs()

-- Get event history
local history = plugin_manager.get_event_history()

-- Clear event history
plugin_manager.clear_event_history()
```

## Configuration

The plugin manager supports various configuration options:

### General Settings
- `auto_clean`: Automatically clean unused plugins
- `log_level`: Logging level (trace, debug, info, warn, error, fatal)

### Loading Settings
- `lazy_load`: Enable lazy loading
- `event_load`: Enable event-based loading
- `cmd_load`: Enable command-based loading
- `ft_load`: Enable filetype-based loading

### Performance Settings
- `n_threads`: Number of threads for parallel operations
- `timeout`: Operation timeout in milliseconds
- `retry`: Number of retry attempts

### Cache Settings
- `cache_enabled`: Enable caching
- `cache_path`: Cache directory path
- `cache_ttl`: Cache time-to-live in seconds

### UI Settings
- `show_status`: Show loading status
- `status_style`: Status display style (minimal, detailed)

### Debug Settings
- `debug`: Enable debug mode
- `profile`: Enable performance profiling

## Event Types

The plugin manager supports various event types:

### Buffer Events
- `BUF_ENTER`: Buffer entered
- `BUF_LEAVE`: Buffer left
- `BUF_WRITE`: Buffer written
- `BUF_READ`: Buffer read

### Vim Events
- `VIM_ENTER`: Vim entered
- `VIM_LEAVE`: Vim left

### Filetype Events
- `FT_DETECT`: Filetype detected

### Command Events
- `CMD_ENTER`: Command line entered
- `CMD_LEAVE`: Command line left

### Insert Events
- `INSERT_ENTER`: Insert mode entered
- `INSERT_LEAVE`: Insert mode left

### Terminal Events
- `TERM_OPEN`: Terminal opened
- `TERM_CLOSE`: Terminal closed

### UI Events
- `UI_ENTER`: UI entered
- `UI_LEAVE`: UI left

### Custom Events
- `PLUGIN_LOAD`: Plugin loaded
- `PLUGIN_UNLOAD`: Plugin unloaded


### Module based configuration
-- lua/plugins/editor.lua
return {
    {
        source = 'nvim-treesitter/nvim-treesitter',
        event = 'BufReadPost',
        priority = 200,
        config = function()
            require('nvim-treesitter.configs').setup({
                ensure_installed = { 'lua', 'python', 'javascript' },
                highlight = { enable = true }
            })
        end,
        post = function()
            vim.cmd('TSUpdate')
        end
    },
    
    {
        source = 'numToStr/Comment.nvim',
        keys = { 'gc', 'gb' },
        config = function()
            require('Comment').setup()
        end
    }
}

### API configuration
-- Add plugins
local plugman = require('plugman')

-- Simple plugin
plugman.add('nvim-tree/nvim-tree.lua', {
    cmd = 'NvimTreeToggle',
    keys = { '<leader>e' },
    config = function()
        require('nvim-tree').setup()
    end
})

-- Complex plugin with dependencies
plugman.add('nvim-telescope/telescope.nvim', {
    depends = { 'nvim-lua/plenary.nvim' },
    cmd = { 'Telescope' },
    keys = {
        { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'Find files' },
        { '<leader>fg', '<cmd>Telescope live_grep<cr>', desc = 'Live grep' }
    },
    priority = 100,
    config = function()
        require('telescope').setup({
            defaults = {
                layout_strategy = 'horizontal'
            }
        })
    end
})

-- Filetype-based loading
plugman.add('fatih/vim-go', {
    ft = 'go',
    config = 'let g:go_highlight_functions = 1'
})

-- Event-based loading
plugman.add('lewis6991/gitsigns.nvim', {
    event = 'BufReadPre',
    config = function()
        require('gitsigns').setup()
    end
})

## Contributing

Feel free to submit issues and enhancement requests! 