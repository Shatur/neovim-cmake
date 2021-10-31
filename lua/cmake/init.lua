local dap = require('dap')
local utils = require('cmake.utils')
local config = require('cmake.config')
local Path = require('plenary.path')
local ProjectConfig = require('cmake.project_config')
local cmake = {}

function cmake.setup(values)
  setmetatable(config, { __index = vim.tbl_extend('force', config.defaults, values) })
end

function cmake.configure(...)
  if not utils.ensure_no_job_active() then
    return
  end

  local cmakelists = Path:new('CMakeLists.txt')
  if not cmakelists:is_file() then
    utils.notify('Unable to find ' .. cmakelists.filename, vim.log.levels.ERROR)
    return
  end

  local project_config = ProjectConfig:new()
  project_config:get_build_dir():mkdir({ parents = true })
  if not project_config:make_query_files() then
    return
  end

  local args = { '-B', project_config:get_build_dir().filename, '-D', 'CMAKE_BUILD_TYPE=' .. project_config.json.build_type, unpack(config.configure_args) }
  vim.list_extend(args, { ... })
  return utils.run('cmake', args, { on_success = project_config:copy_compile_commands() })
end

function cmake.build(...)
  if not utils.ensure_no_job_active() then
    return
  end

  local project_config = ProjectConfig:new()
  if not project_config.json.current_target then
    utils.notify('You need to select target first', vim.log.levels.ERROR)
    return
  end

  local args = { '--build', project_config:get_build_dir().filename, '--target', project_config.json.current_target, unpack(config.build_args) }
  vim.list_extend(args, { ... })
  return utils.run('cmake', args, { on_success = project_config:copy_compile_commands() })
end

function cmake.build_all(...)
  if not utils.ensure_no_job_active() then
    return
  end

  local project_config = ProjectConfig:new()
  return utils.run('cmake', { '--build', project_config:get_build_dir().filename, ... }, { on_success = project_config:copy_compile_commands() })
end

function cmake.run(...)
  if not utils.ensure_no_job_active() then
    return
  end

  local project_config = ProjectConfig:new()
  local target_dir, target, args = project_config:get_current_target()
  if not target then
    return
  end

  vim.list_extend(args, { ... })
  return utils.run(target.filename, args, { cwd = target_dir.filename })
end

function cmake.debug(...)
  if not utils.ensure_no_job_active() then
    return
  end

  local project_config = ProjectConfig:new()
  if not project_config:validate_for_debugging() then
    return
  end

  local target_dir, target, args = project_config:get_current_target()
  if not target then
    return
  end

  vim.list_extend(args, { ... })

  vim.api.nvim_command('cclose')
  local dap_config = {
    name = project_config.json.current_target,
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
  if not utils.ensure_no_job_active() then
    return
  end

  local project_config = ProjectConfig:new()
  local args = { '--build', project_config:get_build_dir().filename, '--target', 'clean' }
  vim.list_extend(args, { ... })
  return utils.run('cmake', args, { on_success = project_config:copy_compile_commands() })
end

function cmake.build_and_run(...)
  if not utils.ensure_no_job_active() then
    return
  end

  if not ProjectConfig:new():get_current_executable_info() then
    return
  end

  return cmake.build(...):after(function()
    vim.schedule(cmake.run)
  end)
end

function cmake.build_and_debug(...)
  if not utils.ensure_no_job_active() then
    return
  end

  local project_config = ProjectConfig:new()
  if not project_config:get_current_executable_info() or not project_config:validate_for_debugging() then
    return
  end

  return cmake.build(...):after_success(function()
    vim.schedule(cmake.debug)
  end)
end

function cmake.set_target_args()
  local project_config = ProjectConfig:new()
  local current_target = project_config:get_current_executable_info()
  if not current_target then
    return
  end

  local current_target_name = current_target['name']
  project_config.json.args[current_target_name] = vim.fn.input(current_target_name .. ' arguments: ', project_config.json.args[current_target_name] or '', 'file')
  project_config:write()
end

function cmake.clear_cache()
  local cache_file = ProjectConfig:new():get_build_dir() / 'CMakeCache.txt'
  if not cache_file:is_file() then
    utils.notify('Cache file ' .. cache_file.filename .. ' does not exists', vim.log.levels.ERROR)
    return
  end

  cache_file:rm()
end

function cmake.open_build_dir()
  local program = vim.fn.has('win32') == 1 and 'start ' or 'xdg-open '
  vim.fn.system(program .. ProjectConfig:new():get_build_dir().filename)
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
