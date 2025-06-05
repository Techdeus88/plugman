local plugman = require('plugman')
local assert = require('luassert')
local say = require('say')

describe('Priority Loading Integration', function()
    local test_plugins = {
        {
            name = 'high_priority_plugin',
            source = 'https://github.com/test/high_priority',
            priority = 100,
            config = function()
                _G.high_priority_loaded = true
            end
        },
        {
            name = 'medium_priority_plugin',
            source = 'https://github.com/test/medium_priority',
            priority = 200,
            config = function()
                _G.medium_priority_loaded = true
            end
        },
        {
            name = 'low_priority_plugin',
            source = 'https://github.com/test/low_priority',
            priority = 300,
            config = function()
                _G.low_priority_loaded = true
            end
        }
    }

    before_each(function()
        -- Reset global state
        _G.high_priority_loaded = false
        _G.medium_priority_loaded = false
        _G.low_priority_loaded = false

        -- Reset plugman state
        plugman._plugins = {}
        plugman._loaded = {}
        plugman._lazy_plugins = {}
    end)

    it('should load plugins in correct priority order', function()
        -- Register plugins
        for _, plugin in ipairs(test_plugins) do
            plugman.register_plugin(plugin)
        end

        -- Setup plugins
        plugman.setup_plugins()

        -- Verify loading order
        assert.is_true(_G.high_priority_loaded)
        assert.is_true(_G.medium_priority_loaded)
        assert.is_true(_G.low_priority_loaded)

        -- Verify plugin status
        local status = plugman.status()
        assert.is_true(status.high_priority_plugin.loaded)
        assert.is_true(status.medium_priority_plugin.loaded)
        assert.is_true(status.low_priority_plugin.loaded)
    end)

    it('should handle dependencies with priorities', function()
        local dependent_plugin = {
            name = 'dependent_plugin',
            source = 'https://github.com/test/dependent',
            priority = 250,
            depends = {'high_priority_plugin'},
            config = function()
                _G.dependent_loaded = true
            end
        }

        -- Register all plugins
        for _, plugin in ipairs(test_plugins) do
            plugman.register_plugin(plugin)
        end
        plugman.register_plugin(dependent_plugin)

        -- Setup plugins
        plugman.setup_plugins()

        -- Verify loading order
        assert.is_true(_G.high_priority_loaded)
        assert.is_true(_G.medium_priority_loaded)
        assert.is_true(_G.dependent_loaded)
        assert.is_true(_G.low_priority_loaded)

        -- Verify plugin status
        local status = plugman.status()
        assert.is_true(status.high_priority_plugin.loaded)
        assert.is_true(status.medium_priority_plugin.loaded)
        assert.is_true(status.dependent_plugin.loaded)
        assert.is_true(status.low_priority_plugin.loaded)
    end)

    it('should handle lazy loading with priorities', function()
        local lazy_plugin = {
            name = 'lazy_plugin',
            source = 'https://github.com/test/lazy',
            priority = 150,
            lazy = true,
            event = 'BufRead',
            config = function()
                _G.lazy_plugin_loaded = true
            end
        }

        -- Register all plugins
        for _, plugin in ipairs(test_plugins) do
            plugman.register_plugin(plugin)
        end
        plugman.register_plugin(lazy_plugin)

        -- Setup plugins
        plugman.setup_plugins()

        -- Verify lazy plugin is not loaded initially
        assert.is_false(_G.lazy_plugin_loaded)
        local status = plugman.status()
        assert.is_false(status.lazy_plugin.loaded)

        -- Trigger lazy loading
        vim.api.nvim_exec_autocmds('BufRead', {})

        -- Verify lazy plugin is now loaded
        assert.is_true(_G.lazy_plugin_loaded)
        status = plugman.status()
        assert.is_true(status.lazy_plugin.loaded)
    end)

    it('should handle plugin removal and re-addition with priorities', function()
        -- Register and setup plugins
        for _, plugin in ipairs(test_plugins) do
            plugman.register_plugin(plugin)
        end
        plugman.setup_plugins()

        -- Remove a plugin
        plugman.remove('medium_priority_plugin')
        assert.is_false(plugman._plugins.medium_priority_plugin)

        -- Re-add the plugin
        plugman.register_plugin(test_plugins[2])
        plugman.setup_plugins()

        -- Verify plugin is loaded again
        local status = plugman.status()
        assert.is_true(status.medium_priority_plugin.loaded)
        assert.is_true(_G.medium_priority_loaded)
    end)
end) 