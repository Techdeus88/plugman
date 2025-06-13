local Logger = require('plugman.utils.logger')

---@class PlugmanPlugin
local Plugin = {}
Plugin.__index = Plugin

---Create new plugin instance
---@param source string Plugin source
---@param opts table Plugin options
---@return PlugmanPlugin
function Plugin.new(source, opts)
  local self = setmetatable({}, Plugin)

  opts = opts or {}

  -- Extract name from source
  self.name = opts.name or self._extract_name(source)
  self.source = source

  -- Core properties
  self.enabled = opts.enabled ~= false
  self.lazy = opts.lazy
  self.priority = opts.priority

  -- Loading triggers
  self.event = opts.event
  self.cmd = opts.cmd
  self.ft = opts.ft
  self.keys = opts.keys

  -- Hooks
  self.init = opts.init
  self.config = opts.config
  self.post = opts.post
  self.hooks = opts.hooks

  -- Dependencies
  self.depends = opts.depends or {}

  -- State
  self.added = false
  self.loaded = false

  -- Determine if plugin should be lazy loaded
  if self.lazy == nil then
    self.lazy = self:_should_be_lazy()
  end

  return self
end

---Create plugin from spec
---@param spec table|string Plugin specification
---@return PlugmanPlugin
function Plugin.from_spec(spec)
  if type(spec) == 'string' then
    return Plugin.new(spec)
  elseif type(spec) == 'table' then
    local source = spec[1] or spec.source
    if not source then
      error("Plugin spec must have source")
    end

    local opts = vim.tbl_deep_extend('force', {}, spec)
    opts[1] = nil
    opts.source = nil

    return Plugin.new(source, opts)
  else
    error("Invalid plugin spec type: " .. type(spec))
  end
end

---Extract plugin name from source
---@param source string Plugin source
---@return string Plugin name
function Plugin._extract_name(source)
  -- Handle GitHub URLs
  if source:match('^https://github%.com/') then
    return source:match('/([^/]+)$')
  end

  -- Handle GitHub shorthand
  if source:match('^[^/]+/[^/]+$') then
    return source:match('/(.+)$')
  end

  -- Handle local paths
  if source:match('^[~/]') then
    return vim.fn.fnamemodify(source, ':t')
  end

  -- Fallback
  return source
end

---Determine if plugin should be lazy loaded
---@return boolean
function Plugin:_should_be_lazy()
  return self.event ~= nil or
      self.cmd ~= nil or
      self.ft ~= nil or
      (self.keys ~= nil and #self.keys > 0)
end

---Check if plugin has loading trigger
---@param trigger_type string Trigger type
---@param value any Trigger value
---@return boolean
function Plugin:has_trigger(trigger_type, value)
  local trigger_value = self[trigger_type]
  if not trigger_value then
    return false
  end

  if type(trigger_value) == 'table' then
    return vim.tbl_contains(trigger_value, value)
  else
    return trigger_value == value
  end
end

---Convert to cache format
---@return table Cache data
function Plugin:to_cache()
  return {
    name = self.name,
    source = self.source,
    added = self.added,
    loaded = self.loaded,
    lazy = self.lazy,
    enabled = self.enabled,
    priority = self.priority,
    event = self.event,
    cmd = self.cmd,
    ft = self.ft,
    depends = self.depends,
    config = self.config,
    init = self.init,
    post = self.post,
    opts = self.opts
  }
end

---Load from cache
---@param data table Cache data
---@return PlugmanPlugin
function Plugin.from_cache(data)
  local plugin = setmetatable({}, Plugin)

  for k, v in pairs(data) do
    plugin[k] = v
  end

  return plugin
end

return Plugin

-- local M = {}

-- -- PlugmanPlugin class
-- local PlugmanPlugin = {}
-- PlugmanPlugin.__index = PlugmanPlugin

-- function PlugmanPlugin.new(spec)
--   local self = setmetatable({}, PlugmanPlugin)

--   -- Handle string specs (simple plugins)
--   if type(spec) == 'string' then
--     spec = { source = spec }
--   end
--   local source = type(spec[1]) == "string" and spec[1] or spec.source
--   -- Extract basic properties
--   self.source = source
--   self.name = self:extract_name(source)
--   self.enabled = spec.enabled ~= false
--   self.lazy = spec.lazy

--   -- Priority handling
--   self.priority = spec.priority or 0

--   -- Lazy loading triggers
--   self.event = type(spec.event) == "string" and { spec.event } or spec.event
--   self.cmd = type(spec.cmd) == "string" and { spec.cmd } or spec.cmd
--   self.ft = type(spec.ft) == "string" and { spec.ft } or spec.ft
--   self.keys = self.keys

--   -- Dependencies
--   self.depends = spec.depends or spec.dependencies

--   -- Hooks
--   self.init = spec.init
--   self.post = spec.post

--   -- MiniDeps options
--   self.checkout = spec.checkout or spec.branch or spec.tag
--   self.monitor = spec.monitor
--   self.hooks = spec.hooks

--   self.config = spec.config
--   -- Additional options
--   self.opts = spec.opts or {}
--   self.require = spec.require or spec.name

--   -- State
--   self.loaded = false
--   self.added = false

--   -- Determine if lazy
--   if self.lazy == nil then
--     self.lazy = self:should_be_lazy()
--   end

--   return self
-- end

-- function PlugmanPlugin:extract_name(source)
--   if not source then return 'unknown' end
--   return source:match('([^/]+)$') or source:match('([^/]+)%.git$') or source
-- end

-- function PlugmanPlugin:should_be_lazy()
--   return self.event or self.cmd or self.ft or self.keys or false
-- end

-- function PlugmanPlugin:get_minideps_spec()
--   local spec = {
--     source = self.source,
--     name = self.name,
--     checkout = self.checkout,
--     monitor = self.monitor,
--     depends = self.depends,
--     hooks = self.hooks or {},
--   }
--   return spec
-- end

-- function PlugmanPlugin:setup_keymaps()
--   local logger = require("plugman.utils.logger")
--   if not self.keys then return end

--   local keys = type(self.keys) == 'function' and self.keys() or self.keys
--   local module_keys = self.keys
--   if type(module_keys) ~= "table" then
--     logger.error(string.format("Invalid keys format for %s", self.name))
--     return
--   end


--   for _, keymap in ipairs(module_keys) do
--     if type(keymap) == "table" and keymap[1] then
--       local opts = {
--         buffer = keymap.buffer,
--         desc = keymap.desc,
--         silent = keymap.silent ~= false,
--         remap = keymap.remap,
--         noremap = keymap.noremap ~= false,
--         nowait = keymap.nowait,
--         expr = keymap.expr,
--       }
--       for _, mode in ipairs(keymap.mode or { "n" }) do
--         vim.keymap.set(mode, keymap[1], keymap[2], opts)
--       end
--     else
--       logger.warn(string.format("Invalid keymap entry for %s", self.name))
--     end
--   end
-- end

-- M.PlugmanPlugin = PlugmanPlugin

-- return M
