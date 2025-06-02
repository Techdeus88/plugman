if vim.g.loaded_plugman then
    return
end
vim.g.loaded_plugman = true
vim.g.plugman_no_auto_setup = true
-- Auto-setup with sensible defaults
if not vim.g.plugman_no_auto_setup then
    require('plugman').setup()
end
