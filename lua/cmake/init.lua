local dap = require('dap')
local utils = require('cmake.utils')
local cmake = {}

function cmake.configure(...)
  if vim.fn.filereadable('CMakeLists.txt') ~= 1 then
    print('Unable to find CMakeLists.txt')
    return
  end

  local additional_arguments = table.concat({...}, ' ')
  local parameters = utils.get_parameters()
  local build_dir = utils.get_build_dir(parameters)
  vim.fn.mkdir(build_dir, 'p')
  utils.make_query_files(build_dir)
  vim.fn['asyncrun#run']('', vim.g.cmake_asyncrun_options, 'cmake ' .. additional_arguments .. ' -D CMAKE_BUILD_TYPE=' .. parameters['buildType'] .. ' -D CMAKE_EXPORT_COMPILE_COMMANDS=1 -B ' .. build_dir .. ' && ln -sf ' .. vim.fn.fnamemodify(build_dir, ':.') .. 'compile_commands.json')
end

function cmake.build(...)
  local parameters = utils.get_parameters()
  local target_name = parameters['currentTarget']
  if not target_name or #target_name == 0 then
    print('You need to select target first')
    return
  end

  local additional_arguments = table.concat({...}, ' ')
  utils.autoclose_quickfix(vim.g.cmake_asyncrun_options)
  vim.fn['asyncrun#run']('', vim.g.cmake_asyncrun_options, 'cmake ' .. additional_arguments .. ' --build ' .. utils.get_build_dir(parameters) .. ' --target ' .. target_name)
end

function cmake.build_all(...)
  local additional_arguments = table.concat({...}, ' ')
  utils.autoclose_quickfix(vim.g.cmake_asyncrun_options)
  vim.fn['asyncrun#run']('', vim.g.cmake_asyncrun_options, 'cmake ' .. additional_arguments .. ' --build ' .. utils.get_build_dir())
end

function cmake.run(...)
  local target_dir, command = utils.get_current_command(utils.get_parameters())
  if not command then
    return
  end

  command = table.concat({command, ...}, ' ')
  utils.autoclose_quickfix(vim.g.cmake_target_asyncrun_options)
  vim.fn['asyncrun#run']('', vim.fn.extend(vim.g.cmake_target_asyncrun_options, {cwd = target_dir}), command)
end

function cmake.debug(...)
  local parameters = utils.get_parameters()
  if not utils.checkDebuggingBuildType(parameters) then
    return
  end

  local target_dir, command = utils.get_current_command(parameters)
  if not command then
    return
  end

  vim.cmd('cclose')
  local config = {
    type = 'cpp',
    name = 'Debug CMake target',
    request = 'launch',
    program = command,
    args = {...},
    cwd = target_dir,
  }
  dap.run(config)
  dap.repl.open()
end

function cmake.clean(...)
  local additional_arguments = table.concat({...}, ' ')
  utils.autoclose_quickfix(vim.g.cmake_asyncrun_options)
  vim.fn['asyncrun#run']('', vim.g.cmake_asyncrun_options, 'cmake ' .. additional_arguments .. '--build ' .. utils.get_build_dir() .. ' --target clean')
end

function cmake.build_and_run(...)
  local parameters = utils.get_parameters()
  if not utils.get_current_executable_info(parameters, utils.get_build_dir(parameters)) then
    return
  end

  vim.cmd('autocmd User AsyncRunStop ++once if g:asyncrun_status ==? "success" | call luaeval("require(\'cmake\').run()") | endif')
  cmake.build(...)
end

function cmake.build_and_debug(...)
  local parameters = utils.get_parameters()
  if not utils.get_current_executable_info(parameters, utils.get_build_dir(parameters)) then
    return
  end

  if not utils.checkDebuggingBuildType(parameters) then
    return
  end

  vim.cmd('autocmd User AsyncRunStop ++once if g:asyncrun_status ==? "success" | call luaeval("require(\'cmake\').debug()") | endif')
  cmake.build(...)
end

function cmake.set_target_arguments()
  local parameters = utils.get_parameters()
  local current_target = utils.get_current_executable_info(parameters, utils.get_build_dir(parameters))
  if not current_target then
    return
  end

  local current_target_name = current_target['name']
  parameters['arguments'][current_target_name] = vim.fn.input(current_target_name .. ' arguments: ', vim.fn.get(parameters['arguments'], current_target_name, ''))
  utils.set_parameters(parameters)
end

function cmake.open_build_dir()
  local program = vim.fn.has('win32') == 1 and 'start ' or 'xdg-open '
  vim.fn.system(program .. utils.get_build_dir())
end

return cmake
