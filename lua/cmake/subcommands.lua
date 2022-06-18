local cmake = require('cmake')
local utils = require('cmake.utils')
local subcommands = {}

function subcommands.complete(arg, cmd_line)
  local matches = {}

  local words = vim.split(cmd_line, ' ', { trimempty = true })
  if not vim.endswith(cmd_line, ' ') then
    -- Last word is not fully typed, don't count it
    table.remove(words, #words)
  end

  if #words == 1 then
    for subcommand in pairs(cmake) do
      if vim.startswith(subcommand, arg) and subcommand ~= 'setup' then
        table.insert(matches, subcommand)
      end
    end
  end

  return matches
end

function subcommands.run(subcommand)
  if #subcommand.fargs == 0 then
    cmake.configure()
    return
  end
  local subcommand_func = cmake[subcommand.fargs[1]]
  if not subcommand_func then
    utils.notify('No such subcommand: ' .. subcommand.fargs[1], vim.log.levels.ERROR)
    return
  end
  local subcommand_info = debug.getinfo(subcommand_func)
  if subcommand_info.isvararg and #subcommand.fargs - 1 < subcommand_info.nparams then
    utils.notify('Subcommand: ' .. subcommand.fargs[1] .. ' should have at least ' .. subcommand_info.nparams .. ' argument(s)', vim.log.levels.ERROR)
    return
  elseif not subcommand_info.isvararg and #subcommand.fargs - 1 ~= subcommand_info.nparams then
    utils.notify('Subcommand: ' .. subcommand.fargs[1] .. ' should have ' .. subcommand_info.nparams .. ' argument(s)', vim.log.levels.ERROR)
    return
  end
  subcommand_func(unpack(subcommand.fargs, 2))
end

return subcommands
