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

function commands.run_command(command)
  if #command.fargs == 0 then
    cmake.configure()
    return
  end
  local command_func = cmake[command.fargs[1]]
  if not command_func then
    utils.notify('No such command: ' .. command.fargs[1], vim.log.levels.ERROR)
    return
  end
  command_func(vim.list_slice(command.fargs, 2, #command.fargs))
end

return commands
