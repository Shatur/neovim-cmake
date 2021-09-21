local M = {}

M.reload = function()
  require('plenary.reload').reload_module('cmake')
end

local log_levels = { 'trace', 'debug', 'info', 'warn', 'error', 'fatal' }
local function set_log_level()
  local log_level = vim.env.NEOVIM_CMAKE_LOG

  for _, level in pairs(log_levels) do
    if level == log_level then
      return log_level
    end
  end

  return 'warn'
end

local log_level = set_log_level()
M.log = require('plenary.log').new({
  plugin = 'neovim-cmake',
  level = log_level,
})

local log_key = os.time()

local function override(key)
  local fn = M.log[key]
  M.log[key] = function(...)
    fn(log_key, ...)
  end
end

for _, v in pairs(log_levels) do
  override(v)
end

M.get_log_key = function()
  return log_key
end

return M
