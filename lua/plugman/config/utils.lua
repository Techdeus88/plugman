local M = {}

function M.get_plugin_path(plugin_name)
    if not plugin_name then return "" end
    if plugin_name == "plugman.nvim" or plugin_name == "mini.deps" then
        local core_path = vim.fn.stdpath "data" .. "/site/pack/deps/start/"
        return string.format("%s%s", core_path, plugin_name) or ""
    end
    local opt_path = vim.fn.stdpath "data" .. "/site/pack/deps/opt/"
    return string.format("%s%s", opt_path, plugin_name) or ""
end

function M.split_plugin_name(plugin_source)
    local name = plugin_source:match "([^/]+)$"
    return name -- This retrieves the name part after the last '/'
end

function M.split_plugin_name_to_require(plugin_name)
    local developer, repo = plugin_name:match "([^.]+)/([^.]+)"
    return developer, repo
end

function M.directory_exists(path)
    local stat = vim.loop.fs_stat(path)
    return stat and stat.type == 'directory'
end

function M.file_exists(path)
    local stat = vim.loop.fs_stat(path)
    return stat and stat.type == 'file'
end

function M.is_installed(plugin)
    local plugin_path = M.get_plugin_path(plugin)
    return M.directory_exists(plugin_path)
end

function M.remove_directory(path)
    if M.directory_exists(path) then
        vim.fn.delete(path, 'rf')
    end
end

function M.get_installed_plugins()
    local core_path = vim.fn.stdpath "data" .. "/site/pack/deps/start/"
    local opt_path = vim.fn.stdpath "data" .. "/site/pack/deps/opt/"

    if not M.directory_exists(core_path) or M.directory_exists(opt_path) then
        return {}
    end

    local plugins = {}
    local handle = vim.loop.fs_scandir(opt_path)

    if handle then
        local name, type = vim.loop.fs_scandir_next(handle)
        while name do
            if type == 'directory' then
                table.insert(plugins, name)
            end
            name, type = vim.loop.fs_scandir_next(handle)
        end
    end

    return plugins
end

function M.ensure_directory(path)
    vim.fn.mkdir(path, 'p')
end

function M.measure_time(func)
    local start_time = vim.fn.reltime()
    func()
    local end_time = vim.fn.reltime(start_time)
    return vim.fn.reltimestr(end_time) * 1000 -- Convert to milliseconds
end

return M
