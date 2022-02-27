local Path = require('plenary.path')
local script_path = Path:new(debug.getinfo(1).source:sub(2))

local config = {
  defaults = {
    cmake_executable = 'cmake',
    parameters_file = 'neovim.json',
    build_dir = tostring(Path:new('{cwd}', 'build', '{os}-{build_type}')),
    samples_path = tostring(script_path:parent():parent():parent() / 'samples'),
    default_projects_path = tostring(Path:new(vim.loop.os_homedir(), 'Projects')),
    configure_args = { '-D', 'CMAKE_EXPORT_COMPILE_COMMANDS=1' },
    build_args = {},
    on_build_output = nil,
    quickfix_height = 10,
    quickfix_only_on_error = false,
    dap_configuration = { type = 'cpp', request = 'launch' },
    dap_open_command = require('dap').repl.open,
  },
}

setmetatable(config, { __index = config.defaults })

return config
