local loader = require('plugman.core.loader')
local assert = require('luassert')
local say = require('say')

-- Helper function to create mock plugins
local function create_mock_plugin(name, priority)
    return {
        name = name,
        source = 'https://github.com/test/' .. name,
        priority = priority,
        config = function() return true end
    }
end

describe('Loader Priority System', function()
    local mock_plugins = {}

    before_each(function()
        mock_plugins = {
            high_priority = create_mock_plugin('high_priority', 100),
            medium_priority = create_mock_plugin('medium_priority', 200),
            low_priority = create_mock_plugin('low_priority', 300),
            default_priority = create_mock_plugin('default_priority', nil)
        }
    end)

    it('should sort plugins by priority (lower numbers first)', function()
        local sorted = {}
        for name, plugin in pairs(mock_plugins) do
            table.insert(sorted, { name = name, opts = plugin })
        end

        table.sort(sorted, function(a, b)
            local priority_a = a.opts.priority or 200
            local priority_b = b.opts.priority or 200
            return priority_a < priority_b
        end)

        assert.equals('high_priority', sorted[1].name)
        assert.equals('medium_priority', sorted[2].name)
        assert.equals('default_priority', sorted[3].name)
        assert.equals('low_priority', sorted[4].name)
    end)

    it('should load plugins in correct priority order', function()
        local load_order = {}
        local original_load_plugin = loader.load_plugin
        loader.load_plugin = function(plugin)
            table.insert(load_order, plugin.name)
            return true
        end

        loader.load_by_priority(mock_plugins)

        assert.equals('high_priority', load_order[1])
        assert.equals('medium_priority', load_order[2])
        assert.equals('default_priority', load_order[3])
        assert.equals('low_priority', load_order[4])

        -- Restore original function
        loader.load_plugin = original_load_plugin
    end)

    it('should handle failed plugin loads', function()
        local load_results = {}
        local original_load_plugin = loader.load_plugin
        loader.load_plugin = function(plugin)
            if plugin.name == 'medium_priority' then
                return false
            end
            return true
        end

        local results = loader.load_by_priority(mock_plugins)

        assert.is_false(results.medium_priority)
        assert.is_true(results.high_priority)
        assert.is_true(results.low_priority)
        assert.is_true(results.default_priority)

        -- Restore original function
        loader.load_plugin = original_load_plugin
    end)

    it('should handle dependencies correctly', function()
        local mock_plugins_with_deps = {
            main = create_mock_plugin('main', 200),
            dep1 = create_mock_plugin('dep1', 100),
            dep2 = create_mock_plugin('dep2', 150)
        }
        mock_plugins_with_deps.main.depends = {'dep1', 'dep2'}

        local load_order = {}
        local original_load_plugin = loader.load_plugin
        loader.load_plugin = function(plugin)
            table.insert(load_order, plugin.name)
            return true
        end

        loader.load_by_priority(mock_plugins_with_deps)

        -- Dependencies should load before the main plugin
        assert.equals('dep1', load_order[1])
        assert.equals('dep2', load_order[2])
        assert.equals('main', load_order[3])

        -- Restore original function
        loader.load_plugin = original_load_plugin
    end)
end) 