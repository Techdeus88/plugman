-- Development script for testing plugman locally
local M = {}

-- Configuration
local config = {
    -- Path to your local Neovim config
    nvim_config = os.getenv('HOME') .. '/.config/nvim-plugman',
    -- Path to your test plugins directory
    test_plugins = os.getenv('HOME') .. '/.config/nvim-plugman/lua/plugins',
    -- Whether to use symlinks or copy files
    use_symlinks = true
 

-- Helper Functions
local function run_command(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

local function ensure_dir(path)
    run_command('mkdir -p ' .. path)
end

local function create_symlink(source, target)
    if config.use_symlinks then
        run_command(string.format('ln -sf %s %s', source, target))
    else
        run_command(string.format('cp -r %s/* %s/', source, target))
    end
end

-- Get Neovim data directory
local function get_nvim_data_dir()
    local xdg_data_home = os.getenv('XDG_DATA_HOME')
    if xdg_data_home then
        return xdg_data_home .. '/nvim'
    end
    return os.getenv('HOME') .. '/.local/share/nvim-plugman'
end

-- Get current working directory
local function get_cwd()
    return run_command('pwd'):gsub('\n', '')
end

-- Development Functions
function M.setup_dev_environment()
    print('Setting up development environment...')

    -- Create necessary directories
    local dev_dir = get_nvim_data_dir() .. '/plugman-dev'
    ensure_dir(dev_dir)

    -- Link or copy plugman to the dev directory
    local current_dir = get_cwd()
    local target_dir = dev_dir .. '/plugman'
    create_symlink(current_dir, target_dir)

    -- Create a test init.lua that uses the dev version
    local init_content = string.format([[
-- Development version of plugman
local dev_path = '%s'
vim.opt.runtimepath:prepend(dev_path)

-- Load your actual config
require('plugins')
]], target_dir)

    local init_file = dev_dir .. '/init.lua'
    local f = io.open(init_file, 'w')
    if f then
        f:write(init_content)
        f:close()
    end

    print('Development environment setup complete!')
    print('To test plugman:')
    print('1. nvim -u ' .. dev_dir .. '/init.lua')
    print('2. Make changes to plugman in this directory')
    print('3. Restart Neovim to see changes')
end

function M.clean_dev_environment()
    print('Cleaning development environment...')
    local dev_dir = get_nvim_data_dir() .. '/plugman-dev'
    run_command('rm -rf ' .. dev_dir)
    print('Development environment cleaned!')
end

function M.run_tests()
    print('Running tests...')
    local test_result = run_command('busted tests/run.lua')
    print(test_result)
end

-- Command line interface
if arg[1] == 'setup' then
    M.setup_dev_environment()
elseif arg[1] == 'clean' then
    M.clean_dev_environment()
elseif arg[1] == 'test' then
    M.run_tests()
else
    print('Usage:')
    print('  lua dev.lua setup  - Setup development environment')
    print('  lua dev.lua clean  - Clean development environment')
    print('  lua dev.lua test   - Run tests')
end

return M
