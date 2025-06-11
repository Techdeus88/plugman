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
  local source = type(spec[1]) == "string" and spec[1] or spec.source
  -- Extract basic properties
  self.source = source
  self.name = self:extract_name(source)
  self.enabled = spec.enabled ~= false
  self.lazy = spec.lazy

  -- Priority handling
  self.priority = spec.priority or 0

  -- Lazy loading triggers
  self.event = type(spec.event) == "string" and { self.event } or self.event
  self.cmd = type(spec.cmd) == "string" and { self.cmd } or self.cmd
  self.ft = type(spec.ft) == "string" and { self.ft } or self.ft
  self.keys = self.keys

  -- Dependencies
  self.depends = spec.depends or self.dependencies

  -- Hooks
  self.init = spec.init
  self.post = spec.post

  -- MiniDeps options
  self.checkout = spec.checkout or spec.branch or spec.tag
  self.monitor = spec.monitor
  self.hooks = spec.hooks

  self.config = spec.config
  -- Additional options
  self.opts = spec.opts or {}
  self.require = spec.require or spec.name

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
    hooks = self.hooks or {},
  }
  return spec
end

function PlugmanPlugin:setup_keymaps()
  local logger = require("plugman.utils.logger")
  if not self.keys then return end

  local keys = type(self.keys) == 'function' and self.keys() or self.keys
  local module_keys = self.keys
  if type(module_keys) ~= "table" then
    logger.error(string.format("Invalid keys format for %s", self.name))
    return
  end


  for _, keymap in ipairs(module_keys) do
    if type(keymap) == "table" and keymap[1] then
      local opts = {
        buffer = keymap.buffer,
        desc = keymap.desc,
        silent = keymap.silent ~= false,
        remap = keymap.remap,
        noremap = keymap.noremap ~= false,
        nowait = keymap.nowait,
        expr = keymap.expr,
      }
      for _, mode in ipairs(keymap.mode or { "n" }) do
        vim.keymap.set(mode, keymap[1], keymap[2], opts)
      end
    else
      logger.warn(string.format("Invalid keymap entry for %s", self.name))
    end
  end
end

M.PlugmanPlugin = PlugmanPlugin

return M
