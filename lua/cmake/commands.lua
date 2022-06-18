local cmake = require('cmake')
local utils = require('cmake.utils')
local commands = {}

function commands.match_commands(arg, cmd_line)
  local matches = {}

  local words = vim.split(cmd_line, ' ', { trimempty = true })
  if not vim.endswith(cmd_line, ' ') then
    -- Last word is not fully typed, don't count it
    table.remove(words, #words)
  end

  if #words == 1 then
    for command in pairs(cmake) do
      if vim.startswith(command, arg) and command ~= 'setup' then
        table.insert(matches, command)
      end
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
  local command_info = debug.getinfo(command_func)
  if not command_info.isvararg and #command.fargs - 1 > command_info.nparams then
    utils.notify('Command: ' .. command.fargs[1] .. ' should have ' .. command_info.nparams .. ' arguments', vim.log.levels.ERROR)
    return
  end
  command_func(table.unpack(command.fargs, 2))
end

return commands
