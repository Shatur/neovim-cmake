local utils = require('cmake.utils')
local config = require('cmake.config')
local scandir = require('plenary.scandir')
local Path = require('plenary.path')
local Job = require('plenary.job')
local ProjectConfig = require('cmake.project_config')
local cmake = {}

function cmake.setup(values) setmetatable(config, { __index = vim.tbl_deep_extend('force', config.defaults, values) }) end

function cmake.configure(...)
  local project_config = ProjectConfig.new()
  project_config:get_build_dir():mkdir({ parents = true })
  if not project_config:make_query_files() then
    return
  end

  local args = vim.list_extend({ '-B', project_config:get_build_dir().filename, '-D', 'CMAKE_BUILD_TYPE=' .. project_config.json.build_type }, config.configure_args)
  vim.list_extend(args, { ... })
  return utils.run(config.cmake_executable, args, { copy_compile_commands_from = project_config:get_build_dir() })
end

function cmake.build(...)
  local project_config = ProjectConfig.new()
  if not project_config.json.current_target then
    utils.notify('You need to select target first', vim.log.levels.ERROR)
    return
  end

  local args = vim.list_extend({ '--build', project_config:get_build_dir().filename, '--target', project_config.json.current_target }, config.build_args)
  vim.list_extend(args, { ... })
  return utils.run(config.cmake_executable, args, { copy_compile_commands_from = project_config:get_build_dir() })
end

function cmake.build_all(...)
  local project_config = ProjectConfig.new()
  local args = vim.list_extend({ '--build', project_config:get_build_dir().filename }, config.build_args)
  vim.list_extend(args, { ... })
  return utils.run(config.cmake_executable, args, { copy_compile_commands_from = project_config:get_build_dir() })
end

function cmake.run(...)
  local project_config = ProjectConfig.new()
  local target_dir, target, target_args = project_config:get_current_target()
  if not target_dir or not target then
    return
  end

  vim.list_extend(target_args, { ... })
  return utils.run(target.filename, target_args, { cwd = target_dir.filename, force_quickfix = true })
end

function cmake.debug(...)
  if not utils.ensure_no_job_active() then
    return
  end

  local project_config = ProjectConfig.new()
  if not project_config:validate_for_debugging() then
    return
  end

  local dap_config = project_config.json.dap_configuration or config.dap_configuration
  if type(dap_config) == 'string' then
    if not config.dap_configurations[dap_config] then
      utils.notify(string.format('`%s` not found in cmakes `dap_configurations` settings', dap_config), vim.log.levels.ERROR)
      return
    end

    dap_config = config.dap_configurations[dap_config]
  end

  local target_dir, target, target_args = project_config:get_current_target()
  if not target_dir or not target then
    return
  end

  vim.list_extend(target_args, { ... })

  local base_dap_config = {
    name = project_config.json.current_target,
    program = target.filename,
    args = target_args,
    cwd = target_dir.filename,
  }

  require('dap').run(vim.tbl_extend('force', base_dap_config, dap_config))
  vim.api.nvim_command('cclose')
  if config.dap_open_command then
    config.dap_open_command()
  end
end

function cmake.clean(...)
  local project_config = ProjectConfig.new()
  local args = vim.list_extend({ '--build', project_config:get_build_dir().filename, '--target', 'clean' }, { ... })
  return utils.run(config.cmake_executable, args, { copy_compile_commands_from = project_config:get_build_dir() })
end

function cmake.build_and_run(...)
  if not ProjectConfig.new():get_current_executable_info() then
    return
  end

  local job = cmake.build(...)
  if job then
    job:after_success(function() vim.schedule(cmake.run) end)
  end
  return job
end

function cmake.build_and_debug(...)
  local project_config = ProjectConfig.new()
  if not project_config:get_current_executable_info() or not project_config:validate_for_debugging() then
    return
  end

  local job = cmake.build(...)
  if job then
    job:after_success(function() vim.schedule(cmake.debug) end)
  end
  return job
end

function cmake.set_target_args()
  local project_config = ProjectConfig.new()
  local current_target = project_config:get_current_executable_info()
  if not current_target then
    return
  end

  local current_target_name = current_target['name']
  vim.ui.input({ prompt = 'Arguments for ' .. current_target_name .. ': ', default = utils.join_args(project_config.json.args[current_target_name]), completion = 'file' }, function(input)
    project_config.json.args[current_target_name] = utils.split_args(input)
    project_config:write()
  end)
end

function cmake.clear_cache()
  local cache_file = ProjectConfig.new():get_build_dir() / 'CMakeCache.txt'
  if not cache_file:is_file() then
    utils.notify('Cache file ' .. cache_file.filename .. ' does not exists', vim.log.levels.ERROR)
    return
  end

  cache_file:rm()
end

function cmake.open_build_dir()
  local job = Job:new({
    command = vim.fn.has('unix') == 1 and 'xdg-open' or 'start',
    args = { ProjectConfig.new():get_build_dir().filename },
  })
  job:start()
end

function cmake.select_build_type()
  -- Put selected build type first
  local project_config = ProjectConfig.new()
  local types = { 'Debug', 'Release', 'RelWithDebInfo', 'MinSizeRel' }
  for idx, type in ipairs(types) do
    if type == project_config.json.build_type then
      table.insert(types, 1, table.remove(types, idx))
      break
    end
  end

  vim.ui.select(types, { prompt = 'Select build type' }, function(build_type)
    if not build_type then
      return
    end
    project_config.json.build_type = build_type
    project_config:write()
  end)
end

function cmake.select_dap_config()
  local project_config = ProjectConfig.new()
  local dap_configs = vim.tbl_keys(config.dap_configurations)
  table.insert(dap_configs, 'Use default')

  vim.ui.select(dap_configs, { prompt = 'Select DAP Configuration' }, function(choice, idx)
    if not idx then
      return
    end
    project_config.json.dap_configuration = idx ~= #dap_configs and choice or nil
    project_config:write()
  end)
end

function cmake.select_target()
  local project_config = ProjectConfig.new()
  if not project_config:get_build_dir():is_dir() then
    utils.notify('You need to configure first', vim.log.levels.ERROR)
    return
  end

  local targets = {}
  local display_targets = {}
  for _, target in ipairs(project_config:get_codemodel_targets()) do
    local target_info = project_config:get_target_info(target)
    local target_name = target_info['name']
    if target_name:find('_autogen') == nil then
      local display_name = target_name .. ' (' .. target_info['type']:lower():gsub('_', ' ') .. ')'
      if target_name == project_config.json.current_target then
        table.insert(targets, 1, target_name)
        table.insert(display_targets, 1, display_name)
      else
        table.insert(targets, target_name)
        table.insert(display_targets, display_name)
      end
    end
  end

  vim.ui.select(display_targets, { prompt = 'Select target' }, function(_, idx)
    if not idx then
      return
    end
    project_config.json.current_target = targets[idx]
    project_config:write()
  end)
end

function cmake.create_project()
  local samples = scandir.scan_dir(config.samples_path, { depth = 1, only_dirs = true })
  for index, sample in ipairs(samples) do
    samples[index] = vim.fn.fnamemodify(sample, ':t')
  end

  vim.ui.select(samples, { prompt = 'Select sample' }, function(sample)
    if not sample then
      return
    end
    vim.ui.input({ prompt = 'Project name: ' }, function(project_name)
      if not project_name then
        utils.notify('Project name cannot be empty', vim.log.levels.ERROR)
        return
      end

      vim.ui.input({ prompt = 'Create in: ', default = config.default_projects_path, completion = 'file' }, function(project_location)
        if not project_location then
          utils.notify('Project path cannot be empty', vim.log.levels.ERROR)
          return
        end

        project_location = Path:new(project_location)
        project_location:mkdir({ parents = true })

        local project_path = project_location / project_name
        if project_path:exists() then
          utils.notify('Path ' .. project_path .. ' is already exists', vim.log.levels.ERROR)
          return
        end

        utils.copy_folder(Path:new(config.samples_path) / sample, project_path)
        vim.api.nvim_command('edit ' .. project_path:joinpath('CMakeLists.txt').filename)
        vim.api.nvim_command('cd %:h')
      end)
    end)
  end)
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
