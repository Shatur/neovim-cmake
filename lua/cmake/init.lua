local dap = require('dap')
local utils = require('cmake.utils')
local config = require('cmake.config')
local Path = require('plenary.path')
local cmake = {}

function cmake.setup(values)
  setmetatable(config, { __index = vim.tbl_extend('force', config.defaults, values) })
end

function cmake.configure(...)
  local cmakelists = Path:new('CMakeLists.txt')
  if not cmakelists:is_file() then
    utils.notify('Unable to find ' .. cmakelists.filename, vim.log.levels.ERROR)
    return
  end

  local parameters = utils.get_parameters()
  local build_dir = utils.get_build_dir(parameters)
  build_dir:mkdir({ parents = true })
  if not utils.make_query_files(build_dir) then
    return
  end

  local args = { '-B', build_dir.filename, '-D', 'CMAKE_BUILD_TYPE=' .. parameters['buildType'], unpack(config.configure_args) }
  vim.list_extend(args, { ... })
  return utils.run('cmake', args, { on_success = utils.copy_compile_commands() })
end

function cmake.build(...)
  local parameters = utils.get_parameters()
  local target_name = parameters['currentTarget']
  if not target_name or #target_name == 0 then
    utils.notify('You need to select target first', vim.log.levels.ERROR)
    return
  end

  local args = { '--build', utils.get_build_dir(parameters).filename, '--target', target_name, unpack(config.build_args) }
  vim.list_extend(args, { ... })
  return utils.run('cmake', args, { on_success = utils.copy_compile_commands() })
end

function cmake.build_all(...)
  return utils.run('cmake', { '--build', utils.get_build_dir().filename, ... }, { on_success = utils.copy_compile_commands() })
end

function cmake.run(...)
  local target_dir, target, args = utils.get_current_target(utils.get_parameters())
  if not target then
    return
  end

  vim.list_extend(args, { ... })
  return utils.run(target.filename, args, { cwd = target_dir.filename })
end

function cmake.debug(...)
  local parameters = utils.get_parameters()
  if not utils.check_debugging_build_type(parameters) then
    return
  end

  local target_dir, target, args = utils.get_current_target(parameters)
  if not target then
    return
  end

  vim.list_extend(args, { ... })

  vim.api.nvim_command('cclose')
  local dap_config = {
    name = parameters['currentTarget'],
    program = target.filename,
    args = args,
    cwd = target_dir.filename,
  }
  dap.run(vim.tbl_extend('force', dap_config, config.dap_configuration))
  if config.dap_open_command then
    config.dap_open_command()
  end
end

function cmake.clean(...)
  local args = { '--build', utils.get_build_dir().filename, '--target', 'clean' }
  vim.list_extend(args, { ... })
  return utils.run('cmake', args, { on_success = utils.copy_compile_commands() })
end

function cmake.build_and_run(...)
  local parameters = utils.get_parameters()
  if not utils.get_current_executable_info(parameters, utils.get_build_dir(parameters)) then
    return
  end

  return cmake.build(...):after(function()
    vim.schedule(cmake.run)
  end)
end

function cmake.build_and_debug(...)
  local parameters = utils.get_parameters()
  if not utils.get_current_executable_info(parameters, utils.get_build_dir(parameters)) then
    return
  end

  if not utils.check_debugging_build_type(parameters) then
    return
  end

  return cmake.build(...):after_success(function()
    vim.schedule(cmake.debug)
  end)
end

function cmake.set_target_args()
  local parameters = utils.get_parameters()
  local current_target = utils.get_current_executable_info(parameters, utils.get_build_dir(parameters))
  if not current_target then
    return
  end

  local current_target_name = current_target['name']
  parameters['args'][current_target_name] = vim.fn.input(current_target_name .. ' arguments: ', parameters['arguments'][current_target_name] or '', 'file')
  utils.set_parameters(parameters)
end

function cmake.clear_cache()
  local cache_file = utils.get_build_dir() / 'CMakeCache.txt'
  if not cache_file:is_file() then
    utils.notify('Cache file ' .. cache_file.filename .. ' does not exists', vim.log.levels.ERROR)
    return
  end

  cache_file:rm()
end

function cmake.open_build_dir()
  local program = vim.fn.has('win32') == 1 and 'start ' or 'xdg-open '
  vim.fn.system(program .. utils.get_build_dir().filename)
end

function cmake.cancel()
  if not utils.last_job or utils.last_job.is_shutdown then
    utils.notify('No running process')
    return
  end

  utils.last_job:shutdown(1, 9)

  if vim.fn.has('win32') == 1 then
    -- Kill all children
    for _, pid in ipairs(vim.api.nvim_get_proc_children(utils.last_job.pid)) do
      vim.loop.kill(pid, 9)
    end
  else
    vim.loop.kill(utils.last_job.pid, 9)
  end
end

return cmake
