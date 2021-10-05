local Path = require('plenary.path')
local script_path = Path:new(debug.getinfo(1).source:sub(2))

local config = {
  defaults = {
    parameters_file = 'neovim.json',
    build_dir = '{cwd}/build/{os}-{build_type}',
    samples_path = script_path:parent():parent():parent() / 'samples',
    default_projects_path = vim.fn.expand('~/Projects'),
    configure_arguments = '-D CMAKE_EXPORT_COMPILE_COMMANDS=1',
    build_arguments = '',
    asyncrun_options = { save = 2 },
    target_asyncrun_options = {},
    dap_configuration = { type = 'cpp', request = 'launch' },
    dap_open_command = require('dap').repl.open,
  },
}

setmetatable(config, { __index = config.defaults })

return config
