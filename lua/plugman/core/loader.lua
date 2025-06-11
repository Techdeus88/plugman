local logger = require('plugman.utils.logger')
local notify = require('plugman.utils.notify')

local M = {}

function M.setup(state)
  -- Setup lazy loading timer
  if #state.loading_order.lazy > 0 then
    vim.defer_fn(function()
      M.load_remaining_lazy_plugins(state)
    end, 2000) -- 2 second delay for lazy plugins without triggers
  end
end

-- Load a single plugin
function M.load_plugin(plugin)
  if plugin.loaded then return end
  
  logger.info("Loading plugin: " .. plugin.name)
  
  -- Run init hook
  if plugin.init then
    local ok, err = pcall(plugin.init)
    if not ok then
      logger.error("Init hook failed for " .. plugin.name .. ": " .. err)
    end
  end
  
  -- Install with MiniDeps
  local minideps = require('mini.deps')
  local spec = plugin:get_minideps_spec()
  minideps.add(spec)
  
  -- Setup keymaps
  plugin:setup_keymaps()
  
  -- Run post hook
  if plugin.post then
    local ok, err = pcall(plugin.post)
    if not ok then
      logger.error("Post hook failed for " .. plugin.name .. ": " .. err)
    end
  end
  
  plugin.loaded = true
  plugin.installed = true
  
  logger.debug("Loaded plugin: " .. plugin.name)
end

-- Setup lazy loading for a plugin
function M.setup_lazy_loading(plugin)
  logger.debug("Setting up lazy loading for: " .. plugin.name)
  
  -- Event-based loading
  if plugin.event then
    local events = type(plugin.event) == 'table' and plugin.event or { plugin.event }
    
    vim.api.nvim_create_autocmd(events, {
      callback = function()
        M.load_plugin(plugin)
        return true -- Remove autocmd after first trigger
      end,
      desc = "Lazy load " .. plugin.name
    })
  end
  
  -- Command-based loading
  if plugin.cmd then
    local commands = type(plugin.cmd) == 'table' and plugin.cmd or { plugin.cmd }
    
    for _, cmd in ipairs(commands) do
      vim.api.nvim_create_user_command(cmd, function(opts)
        M.load_plugin(plugin)
        -- Re-execute the command
        vim.cmd(cmd .. ' ' .. (opts.args or ''))
      end, { 
        nargs = '*', 
        desc = "Lazy load " .. plugin.name 
      })
    end
  end
  
  -- Filetype-based loading
  if plugin.ft then
    local filetypes = type(plugin.ft) == 'table' and plugin.ft or { plugin.ft }
    
    vim.api.nvim_create_autocmd('FileType', {
      pattern = filetypes,
      callback = function()
        M.load_plugin(plugin)
      end,
      desc = "Lazy load " .. plugin.name
    })
  end
  
  -- Key-based loading
  if plugin.keys then
    local keys = type(plugin.keys) == 'table' and plugin.keys or { plugin.keys }
    
    for _, keymap in ipairs(keys) do
      if type(keymap) == 'table' then
        local lhs = keymap[1]
        local rhs = keymap[2]
        local opts = vim.tbl_extend('force', { desc = plugin.name }, keymap.opts or {})
        
        -- Create temporary keymap that loads plugin
        vim.keymap.set(keymap.mode or 'n', lhs, function()
          M.load_plugin(plugin)
          -- Execute the actual keymap
          if type(rhs) == 'function' then
            rhs()
          else
            vim.cmd(rhs)
          end
        end, opts)
      end
    end
  end
end

-- Load remaining lazy plugins (fallback after timer)
function M.load_remaining_lazy_plugins(state)
  for _, plugin in ipairs(state.loading_order.lazy) do
    if not plugin.loaded and plugin.lazy == true then
      M.load_plugin(plugin)
    end
  end
end

return M