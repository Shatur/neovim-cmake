local actions = require('telescope.actions')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')
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

function cmake.select_build_type()
  local parameters = utils.get_parameters()
  local current_build_type = parameters['buildType']
  local types = {}
  for _, type in ipairs({'Debug', 'Release', 'RelWithDebInfo', 'MinSizeRel'}) do
    if type == current_build_type then
      table.insert(types, 1, type)
    else
      table.insert(types, type)
    end
  end

  pickers.new({}, {
    prompt_title = 'Select build type',
    finder = finders.new_table {
      results = types
    },
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      local set_build_type = function()
        actions.close(prompt_bufnr)
        parameters['buildType'] = actions.get_selected_entry(prompt_bufnr).display
        utils.set_parameters(parameters)
      end

      map('i', '<CR>', set_build_type)
      return true
    end,
  }):find()
end

function cmake.select_target()
  local parameters = utils.get_parameters()
  local build_dir = utils.get_build_dir(parameters)
  if vim.fn.isdirectory(build_dir) ~= 1 then
    print('You need to configure first')
    return
  end

  local targets = {}
  local current_target = parameters['currentTarget']
  local reply_dir = utils.get_reply_dir(build_dir)
  for _, target in ipairs(utils.get_codemodel_targets(reply_dir)) do
    local target_info = utils.get_target_info(reply_dir, target)
    local target_name = target_info['name']
    local target_type = target_info['type']
    if target_type ~= 'UTILITY' then
      if target_name == current_target then
        table.insert(targets, 1, target_name .. ' (' .. vim.fn.tolower(target_type) .. ')')
      else
        table.insert(targets, target_name .. ' (' .. vim.fn.tolower(target_type) .. ')')
      end
    end
  end

  pickers.new({}, {
    prompt_title = 'Select target',
    finder = finders.new_table {
      results = targets
    },
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      local set_build_type = function()
        actions.close(prompt_bufnr)
        local value = actions.get_selected_entry(prompt_bufnr).display
        parameters['currentTarget'] = vim.fn.strpart(value, 0, vim.fn.stridx(value, ' '))
        utils.set_parameters(parameters)
      end

      map('i', '<CR>', set_build_type)
      return true
    end,
  }):find()
end

function cmake.create_project()
  local project_name = vim.fn.input('Project name: ')
  if #project_name == 0 then
    vim.cmd('redraw')
    print('Project name cannot be empty')
    return
  end

  local project_location = vim.fn.input('Create in: ', vim.g.default_cmake_projects_path, 'file')
  if #project_location == 0 then
    vim.cmd('redraw')
    print('Project path cannot be empty')
    return
  end
  vim.fn.mkdir(project_location, 'p')

  local project_path = vim.fn.expand(project_location) .. '/' .. project_name

  if #vim.fn.glob(project_path) ~= 0 then
    vim.cmd('redraw')
    print('Path ' .. project_path .. ' is already exists')
    return
  end

  local samples = vim.fn.map(vim.fn.glob(vim.g.cmake_samples_path .. '*', true, true), 'fnamemodify(v:val, ":t")')
  pickers.new({}, {
    prompt_title = 'Select sample',
    finder = finders.new_table {
      results = samples
    },
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      local set_build_type = function()
        actions.close(prompt_bufnr)
        local sample_name = actions.get_selected_entry(prompt_bufnr).display
        local output = vim.fn.system('cp -r "' .. vim.g.cmake_samples_path .. sample_name .. '" "' .. project_path .. '"')
        if #output ~= 0 then
          print(output)
          return
        end

        vim.cmd('edit ' .. project_path .. '/CMakeLists.txt')
        vim.cmd('cd %:h')
      end

      map('i', '<CR>', set_build_type)
      return true
    end,
  }):find()
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
