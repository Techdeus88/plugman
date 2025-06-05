local busted = require('busted')
local handler = require('busted.outputHandlers.base')()

-- Configure busted
busted.setup({
    output = handler,
    verbose = true,
    suppressPending = false,
    language = 'en'
})

-- Add test files
local test_files = {
    'tests/unit/loader_test.lua',
    'tests/integration/priority_loading_test.lua'
}

-- Run tests
busted.run(test_files)
