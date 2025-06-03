if vim.g.loaded_plugman then
    return
end
if vim.g.plugman_no_auto_setup == nil then
    vim.g.plugman_no_auto_setup = true
end
-- Auto-setup with sensible defaults
if not vim.g.plugman_no_auto_setup then
    require('plugman').setup()
end
vim.g.loaded_plugman = true
