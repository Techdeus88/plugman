local M = {}

local logger = require('plugman.utils.logger')

---Show plugin management UI
function M.show()
    local plugman = require('plugman')
    local plugins = plugman.status()

    -- Create background buffer and window
    local bg_buf = vim.api.nvim_create_buf(false, true)
    local bg_win = vim.api.nvim_open_win(bg_buf, false, {
        relative = 'editor',
        width = vim.o.columns,
        height = vim.o.lines,
        col = 0,
        row = 0,
        style = 'minimal',
        zindex = 1
    })

    -- Set background color
    vim.api.nvim_win_set_option(bg_win, 'winblend', 0)
    vim.api.nvim_win_set_option(bg_win, 'winhighlight', 'Normal:NormalNC')

    -- Create a new buffer for main content
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = math.floor(vim.o.columns * 0.8),
        height = math.floor(vim.o.lines * 0.8),
        col = math.floor(vim.o.columns * 0.1),
        row = math.floor(vim.o.lines * 0.1),
        style = 'minimal',
        border = 'rounded',
        title = ' Plugman ',
        title_pos = 'center',
        zindex = 2
    })

    -- Generate content
    local lines = { '# Plugman - Plugin Manager', '', '## Installed Plugins', '' }

    for name, status in pairs(plugins) do
        local state = status.loaded and '✓' or (status.lazy and '⏳' or '✗')
        local line = string.format('%s %s', state, name)

        if status.config and status.config.priority then
            line = line .. string.format(' (priority: %d)', status.config.priority)
        end

        table.insert(lines, line)
    end

    table.insert(lines, '')
    table.insert(lines, '## Legend')
    table.insert(lines, '✓ Loaded')
    table.insert(lines, '⏳ Lazy (not loaded)')
    table.insert(lines, '✗ Not loaded')
    table.insert(lines, '')
    table.insert(lines, 'Press q to close')

    -- Set buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')

    -- Set keymaps
    vim.keymap.set('n', 'q', function()
        vim.api.nvim_win_close(win, true)
        vim.api.nvim_win_close(bg_win, true)
    end, { buffer = buf })

    vim.keymap.set('n', 'r', function()
        M.show() -- Refresh
        vim.api.nvim_win_close(win, true)
        vim.api.nvim_win_close(bg_win, true)
    end, { buffer = buf })

    logger.debug('Opened Plugman UI')
end

function M.show_plugin_detail()
    local plugman = require('plugman')

    local plugins = {
        priority = plugman._priority_plugins,
        now = plugman._now_plugins,
        lazy = plugman._lazy_plugins
    }
    local lines = {
        "All Plugins"
    }
    local p_number = 1
    local total_plugins = 0
    for type, p in pairs(plugins) do
        local total_type_plugs = #p
        local title_line = string.format("----------%s plugins-----------", type)
        table.insert(lines, title_line)
        for name, plugin in pairs(p) do\
            local plugin_line = string.format("%s) %s-%s", p_number, name, plugin.type)
            table.insert(lines, plugin_line)
            table.insert(lines, "----------------------")
            p_number = p_number + 1
        end
        local end_line = string.format("-------%s plugins--------", total_type_plugs)
        table.insert(lines, end_line)
        table.insert(lines, "----------------------")
        table.insert(lines, "----------------------")
        total_plugins = total_plugins + total_type_plugs
    end
    table.insert(lines, "----------------------")
    table.insert(lines, "----------------------")
    table.insert(lines, string.format("Total Plugins: %d", total_plugins))

    -- Create background buffer and window
    local bg_buf = vim.api.nvim_create_buf(false, true)
    local bg_win = vim.api.nvim_open_win(bg_buf, false, {
        relative = 'editor',
        width = vim.o.columns,
        height = vim.o.lines,
        col = 0,
        row = 0,
        style = 'minimal',
        zindex = 1
    })

    -- Set background color
    vim.api.nvim_win_set_option(bg_win, 'winblend', 0)
    vim.api.nvim_win_set_option(bg_win, 'winhighlight', 'Normal:NormalNC')

    -- Create a new buffer for main content
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = math.floor(vim.o.columns * 0.8),
        height = math.floor(vim.o.lines * 0.8),
        col = math.floor(vim.o.columns * 0.1),
        row = math.floor(vim.o.lines * 0.1),
        style = 'minimal',
        border = 'rounded',
        title = ' Plugman ',
        title_pos = 'center',
        zindex = 2
    })


    -- Set buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')

    -- Set keymaps
    vim.keymap.set('n', 'q', function()
        vim.api.nvim_win_close(win, true)
        vim.api.nvim_win_close(bg_win, true)
    end, { buffer = buf })

    vim.keymap.set('n', 'r', function()
        M.show() -- Refresh
        vim.api.nvim_win_close(win, true)
        vim.api.nvim_win_close(bg_win, true)
    end, { buffer = buf })

    logger.debug('Opened Plugman Plugin UI')
end

return M
