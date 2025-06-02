-- Start-of-file--
-- Auto-setup Plugman commands

vim.api.nvim_create_user_command('PlugmanShow', function()
    require('plugman.ui').show()
end, { desc = 'Show Plugman UI' })

vim.api.nvim_create_user_command('PlugmanUpdate', function(args)
    local plugman = require('plugman')
    plugman.update(args.args ~= '' and args.args or nil)
end, {
    nargs = '?',
    desc = 'Update plugins'
})

vim.api.nvim_create_user_command('PlugmanHealth', function()
    require('plugman.utils.health').check()
end, { desc = 'Check Plugman health' })

vim.api.nvim_create_user_command('PlugmanAdd', function(args)
    local parts = vim.split(args.args, ' ', { trimempty = true })
    local source = parts[1]
    local config = parts[2]

    require('plugman').add(source, config)
end, {
    nargs = '+',
    desc = 'Add a plugin'
})
--End-of-file--