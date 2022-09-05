local Path = require('plenary.path')
local script_path = Path:new(debug.getinfo(1).source:sub(2))

local config = {
  defaults = {
    cmake_executable = 'cmake',
    save_before_build = true,
    parameters_file = 'neovim.json',
    default_parameters = { args = {}, build_type = 'Debug' },
    build_dir = tostring(Path:new('{cwd}', 'build', '{os}-{build_type}')),
    samples_path = tostring(script_path:parent():parent():parent() / 'samples'),
    default_projects_path = tostring(Path:new(vim.loop.os_homedir(), 'Projects')),
    configure_args = { '-D', 'CMAKE_EXPORT_COMPILE_COMMANDS=1' },
    build_args = {},
    on_build_output = nil,
    quickfix = {
      pos = 'botright',
      height = 10,
      only_on_error = false,
    },
    copy_compile_commands = true,
    dap_configurations = {
      lldb_vscode = { type = 'lldb', request = 'launch' },
      cppdbg_vscode = { type = 'cppdbg', request = 'launch' },
    },
    dap_configuration = 'lldb_vscode',
    dap_open_command = function(...) return require('dap').repl.open(...) end,
  },
}

setmetatable(config, { __index = config.defaults })

return config
