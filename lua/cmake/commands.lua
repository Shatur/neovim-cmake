local cmake = require('cmake')
local commands = {}

function commands.match_commands(arg)
  local matches = {}
  for command in pairs(cmake) do
    if vim.startswith(command, arg) then
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
    print('No such command: ' .. command)
    return
  end
  command_func(...)
end

return commands
