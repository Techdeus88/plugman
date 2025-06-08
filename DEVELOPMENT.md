# Development Guide for Plugman

This guide explains how to set up a development environment for testing and developing Plugman.

## Prerequisites

- Neovim (latest version recommended)
- Lua (5.1 or later)
- Busted (for running tests)
- Git

## Development Setup

1. Clone the repository:
```bash
git clone https://github.com/Techdeus88/plugman
cd plugman
```

2. Set up the development environment:
```bash
lua dev.lua setup
```

This will:
- Create a development directory in your Neovim data directory
- Set up symlinks to your local plugman repository
- Create a test init.lua that uses your development version

## Testing Your Changes

1. Make changes to the code in your local repository

2. Test your changes:
```bash
# Run the test suite
lua dev.lua test

# Test in Neovim
nvim -u ~/.local/share/nvim-plugman/plugman-dev/init.lua
```

3. If you want to test with your actual Neovim configuration:
   - Edit the `dev.lua` file and update the `nvim_config` path
   - The development environment will use your actual plugins directory

## Development Workflow

1. Make changes to the code
2. Run tests to ensure nothing is broken
3. Test in Neovim with the development environment
4. If everything works, commit your changes

## Cleaning Up

To remove the development environment:
```bash
lua dev.lua clean
```

## Debugging

- Use `:checkhealth plugman` in Neovim to check for issues
- Check the Neovim log file for errors
- Use the logger in the code for debugging:
```lua
local logger = require('plugman.utils.logger')
logger.debug('Debug message')
logger.error('Error message')
```

## Running Tests

The test suite uses Busted. To run tests:

```bash
# Run all tests
lua dev.lua test

# Run specific test file
busted tests/unit/loader_test.lua
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## Common Issues

1. **Symlink issues**: If you're on Windows, you might need to run as administrator or use the copy method instead of symlinks
2. **Path issues**: Make sure your paths in `dev.lua` are correct for your system
3. **Test failures**: Check if you have all required dependencies installed

## Tips

- Use `:PlugmanStatus` in Neovim to check plugin status
- The development environment uses your actual plugins, so you can test with real-world scenarios
- Keep the test suite updated as you add new features 