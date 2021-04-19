local utils = {}

function utils.get_os_name()
  if vim.fn.has('mac') == 1 then
    return 'mac'
  elseif vim.fn.has('unix') == 1 then
    return 'unix'
  elseif vim.fn.has('win32') == 1 then
    return 'win'
  elseif vim.has('bsd') == 1 then
    return 'bsd'
  else
    return 'unknown'
  end
end

function utils.get_parameters()
  if vim.fn.filereadable(vim.g.cmake_parameters_file) ~= 1 then
    return {currentTarget = '', buildType = 'Debug', arguments = {}}
  end
  return vim.fn.json_decode(vim.fn.readfile(vim.g.cmake_parameters_file))
end

function utils.set_parameters(parameters)
  vim.fn.writefile({vim.fn.json_encode(parameters)}, vim.g.cmake_parameters_file)
end

function utils.get_build_dir(parameters)
  if not parameters then
    parameters = utils.get_parameters()
  end

  local build_dir = vim.g.cmake_build_dir .. '/'
  build_dir = build_dir:gsub('{cwd}', vim.fn.getcwd())
  build_dir = build_dir:gsub('{os}', utils.get_os_name())
  build_dir = build_dir:gsub('{build_type}', parameters['buildType'])
  return build_dir
end

function utils.get_reply_dir(build_dir)
  return build_dir .. '.cmake/api/v1/reply/'
end

function utils.get_codemodel_targets(reply_dir)
  local codemodel_json = vim.fn.json_decode(vim.fn.readfile(vim.fn.globpath(reply_dir, 'codemodel*')))
  return codemodel_json['configurations'][1]['targets']
end

function utils.get_target_info(reply_dir, codemodel_target)
  return vim.fn.json_decode(vim.fn.readfile(reply_dir .. codemodel_target['jsonFile']))
end

-- Tell CMake to generate codemodel
function utils.make_query_files(build_dir)
  local query_dir = build_dir .. '.cmake/api/v1/query/'
  vim.fn.mkdir(query_dir, 'p')

  local codemodel_file = query_dir .. 'codemodel-v2'
  if vim.fn.filereadable(codemodel_file) ~= 1 then
    vim.fn.writefile({}, codemodel_file)
  end
end

function utils.get_current_executable_info(parameters, build_dir)
  if vim.fn.isdirectory(build_dir) ~= 1 then
    print('You need to configure first')
    return nil
  end

  local target_name = parameters['currentTarget']
  if not target_name then
    print('You need to select target first')
    return nil
  end

  local reply_dir = utils.get_reply_dir(build_dir)
  for _, target in ipairs(utils.get_codemodel_targets(reply_dir)) do
    if target_name == target['name'] then
      local target_info = utils.get_target_info(reply_dir, target)
      if target_info['type'] ~= 'EXECUTABLE' then
        print('Specified target is not executable: ' .. target_name)
        return nil
      end
      return target_info
    end
  end

  print('Unable to find the following target: ' .. target_name)
  return nil
end

function utils.get_current_command(parameters)
  local build_dir = utils.get_build_dir(parameters)
  local target_info = utils.get_current_executable_info(parameters, build_dir)
  if not target_info then
    return nil, nil
  end

  local command = build_dir .. target_info['artifacts'][1]['path']
  if vim.fn.filereadable(command) ~= 1 then
    print('Selected target is not built: ' .. command)
    return nil, nil
  end

  local target_dir = vim.fn.fnamemodify(command, ":h")
  local arguments = parameters['arguments'][target_info['name']]
  if arguments then
    command = command .. ' ' .. arguments
  end
  return target_dir, command
end

function utils.asyncrun_callback(function_string)
  vim.cmd('autocmd User AsyncRunStop ++once if g:asyncrun_status ==? "success" | call luaeval("' .. function_string .. '") | endif')
end

function utils.autocopy_compile_commands()
  local generated_commands = io.open(utils.get_build_dir() .. '/compile_commands.json')
  if not generated_commands then
    return
  end

  local output_commands = assert(io.open(vim.fn.getcwd() .. '/compile_commands.json', 'w'))
  output_commands:write(generated_commands:read('*all'))
end

function utils.autoclose_quickfix(options)
  if vim.fn.get(options, 'mode', 'async') ~= 'async' then
    vim.cmd('cclose')
  end
end

function utils.check_debugging_build_type(parameters)
  local buildType = parameters['buildType']
  if buildType ~= 'Debug' and buildType ~= 'RelWithDebInfo' then
    print('For debugging you need to use Debug or RelWithDebInfo, but currently your build type is ' .. buildType)
    return false
  end
  return true
end

return utils
