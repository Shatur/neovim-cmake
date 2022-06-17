local cmake = require('cmake')
local utils = require('cmake.utils')
local commands = {}

function commands.match_commands(arg, cmd_line)
  local matches = {}

  local _, words_count = cmd_line:gsub('%S+', '')
  if not vim.endswith(cmd_line, ' ') then
    -- Last word is not fully typed, don't count it
    words_count = words_count - 1
  end

  if words_count == 1 then
    -- We complete only first arg
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
  command_func(vim.list_slice(command.fargs, 2, #command.fargs))
end

return commands
