local cmake = require('cmake')
local utils = require('cmake.utils')
local commands = {}

function commands.match_commands(arg)
  local matches = {}
  for command in pairs(cmake) do
    if vim.startswith(command, arg) and command ~= 'setup' then
      table.insert(matches, command)
    end
  end
  return matches
end

function commands.run_command(command, ...)
  if not command then
    cmake.configure()
    return
  end
  local command_func = cmake[command]
  if not command_func then
    utils.notify('No such command: ' .. command, vim.log.levels.ERROR)
    return
  end
  command_func(...)
end

return commands
