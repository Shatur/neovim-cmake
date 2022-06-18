if not vim.fn.has('nvim-0.7.0') then
  require('cmake.utils').notify('Neovim 0.7+ is required for cmake plugin', vim.log.levels.ERROR)
  return
end

local subcommands = require('cmake.subcommands')

vim.api.nvim_create_user_command('CMake', subcommands.run, { nargs = '*', complete = subcommands.match, desc = 'Run CMake command' })
