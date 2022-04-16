if not vim.fn.has('nvim-0.7.0') then
  require('cmake.utils').notify('Neovim 0.7+ is required for cmake plugin', vim.log.levels.ERROR)
  return
end

local cmake_commands = require('cmake.commands')
vim.api.nvim_create_user_command('CMake', cmake_commands.run_command, { nargs = '*', complete = cmake_commands.match_commands })
