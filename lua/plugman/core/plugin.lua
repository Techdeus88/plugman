local M = {}

-- PlugmanPlugin class
local PlugmanPlugin = {}
PlugmanPlugin.__index = PlugmanPlugin

function PlugmanPlugin.new(spec)
  local self = setmetatable({}, PlugmanPlugin)
  
  -- Handle string specs (simple plugins)
  if type(spec) == 'string' then
    spec = { source = spec }
  end
  
  -- Extract basic properties
  self.source = spec[1] or spec.source
  self.name = spec.name or self:extract_name(self.source)
  self.enabled = spec.enabled ~= false
  self.lazy = spec.lazy
  
  -- Priority handling
  self.priority = spec.priority or 0
  
  -- Lazy loading triggers
  self.event = spec.event
  self.cmd = spec.cmd
  self.ft = spec.ft
  self.keys = spec.keys
  
  -- Dependencies
  self.depends = spec.depends or spec.dependencies or {}
  
  -- Hooks
  self.init = spec.init
  self.post = spec.post or spec.config
  
  -- MiniDeps options
  self.checkout = spec.checkout or spec.branch or spec.tag
  self.monitor = spec.monitor
  self.hooks = spec.hooks
  
  -- Additional options
  self.opts = spec.opts or {}
  
  -- State
  self.loaded = false
  self.added = false
  
  -- Determine if lazy
  if self.lazy == nil then
    self.lazy = self:should_be_lazy()
  end
  
  return self
end

function PlugmanPlugin:extract_name(source)
  if not source then return 'unknown' end
  return source:match('([^/]+)$') or source:match('([^/]+)%.git$') or source
end

function PlugmanPlugin:should_be_lazy()
  return self.event or self.cmd or self.ft or self.keys or false
end

function PlugmanPlugin:get_minideps_spec()
  local spec = {
    source = self.source,
    name = self.name,
    checkout = self.checkout,
    monitor = self.monitor,
    depends = self.depends,
    hooks = self.hooks
  }
  
  if self.init then
    spec.hooks.pre_install = self.init
  end
  
  if self.post then
    spec.hooks.post_install = self.post
  end
  
  return spec
end

function PlugmanPlugin:setup_keymaps()
  if not self.keys then return end
  
  local keys = type(self.keys) == 'table' and self.keys or { self.keys }
  
  for _, keymap in ipairs(keys) do
    if type(keymap) == 'table' then
      local lhs = keymap[1]
      local rhs = keymap[2]
      local opts = vim.tbl_extend('force', { desc = self.name }, keymap.opts or {})
      
      vim.keymap.set(keymap.mode or 'n', lhs, rhs, opts)
    end
  end
end

M.PlugmanPlugin = PlugmanPlugin

return M