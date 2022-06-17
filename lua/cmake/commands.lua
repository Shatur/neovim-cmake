local cmake = require('cmake')
local utils = require('cmake.utils')
local commands = {}

function commands.match_commands(arg, cmd_line)
  local words_count = 0
  local last_space_pos = 0
  repeat
    last_space_pos = string.find(cmd_line, ' ', last_space_pos + 1)
    words_count = words_count + 1
  until last_space_pos == nil
  if words_count > 2 then
    -- We complete only first arg (2 is for command and its argument)
    return {}
  end

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
