local os = require('ffi').os:lower()
local Job = require('plenary.job')
local Path = require('plenary.path')
local config = require('cmake.config')
local scandir = require('plenary.scandir')
local utils = { last_job = nil }

local function print_output(error, data)
    vim.schedule(function()
      vim.fn.setqflist({}, 'a', { lines = { error and error or data } })
      if vim.bo.buftype ~= 'quickfix' then
        vim.api.nvim_command('cbottom')
      end
    end)
end

local function split_args(args)
  if not args then
    return {}
  end

  -- Split on spaces unless "in quotes"
  local splitted_args = vim.fn.split(args, [[\s\%(\%([^'"]*\(['"]\)[^'"]*\1\)*[^'"]*$\)\@=]])

  -- Remove quotes
  for i, arg in ipairs(splitted_args) do
    splitted_args[i] = arg:gsub('"', ''):gsub("'", '')
  end
  return splitted_args
end

function utils.notify(msg, log_level)
  vim.notify(msg, log_level, { title = 'CMake' })
end

function utils.get_parameters()
  local parameters_file = Path:new(config.parameters_file)
  if not parameters_file:is_file() then
    return { currentTarget = '', buildType = 'Debug', args = {} }
  end
  return vim.fn.json_decode(parameters_file:read())
end

function utils.set_parameters(parameters)
  local parameters_file = Path:new(config.parameters_file)
  parameters_file:write(vim.fn.json_encode(parameters), 'w')
end

function utils.get_build_dir(parameters)
  if not parameters then
    parameters = utils.get_parameters()
  end

  local build_dir = tostring(config.build_dir)
  build_dir = build_dir:gsub('{cwd}', vim.fn.getcwd())
  build_dir = build_dir:gsub('{os}', os)
  build_dir = build_dir:gsub('{build_type}', parameters['buildType']:lower())
  return Path:new(build_dir)
end

function utils.get_reply_dir(build_dir)
  return build_dir / '.cmake' / 'api' / 'v1' / 'reply'
end

function utils.get_codemodel_targets(reply_dir)
  local codemodel = Path:new(vim.fn.globpath(reply_dir.filename, 'codemodel*'))
  local codemodel_json = vim.fn.json_decode(codemodel:read())
  return codemodel_json['configurations'][1]['targets']
end

function utils.get_target_info(reply_dir, codemodel_target)
  return vim.fn.json_decode((reply_dir / codemodel_target['jsonFile']):read())
end

-- Tell CMake to generate codemodel
function utils.make_query_files(build_dir)
  local query_dir = build_dir / '.cmake' / 'api' / 'v1' / 'query'
  if not query_dir:mkdir({ parents = true }) then
    utils.notify('Unable to create folder ' .. query_dir.filename, vim.log.levels.ERROR)
    return false
  end

  local codemodel_file = query_dir / 'codemodel-v2'
  if not codemodel_file:is_file() then
    if not codemodel_file:touch() then
      utils.notify('Unable to create file ' .. codemodel_file.filename, vim.log.levels.ERROR)
      return false
    end
  end
  return true
end

function utils.get_current_executable_info(parameters, build_dir)
  if not build_dir:is_dir() then
    utils.notify('You need to configure first', vim.log.levels.ERROR)
    return nil
  end

  local target_name = parameters['currentTarget']
  if not target_name then
    utils.notify('You need to select target first', vim.log.levels.ERROR)
    return nil
  end

  local reply_dir = utils.get_reply_dir(build_dir)
  for _, target in ipairs(utils.get_codemodel_targets(reply_dir)) do
    if target_name == target['name'] then
      local target_info = utils.get_target_info(reply_dir, target)
      if target_info['type'] ~= 'EXECUTABLE' then
        utils.notify('Specified target is not executable: ' .. target_name, vim.log.levels.ERROR)
        return nil
      end
      return target_info
    end
  end

  utils.notify('Unable to find the following target: ' .. target_name, vim.log.levels.ERROR)
  return nil
end

function utils.get_current_target(parameters)
  local build_dir = utils.get_build_dir(parameters)
  local target_info = utils.get_current_executable_info(parameters, build_dir)
  if not target_info then
    return nil, nil
  end

  local target = build_dir / target_info['artifacts'][1]['path']
  if not target:is_file() then
    utils.notify('Selected target is not built: ' .. target.filename, vim.log.levels.ERROR)
    return nil, nil
  end

  local target_dir = parameters['runDir']
  if target_dir == nil then
    target_dir = target:parent()
  end
  local args = parameters['args']
  local target_args = args and split_args(parameters['args'][target_info['name']]) or {}
  return target_dir, target, target_args
end

function utils.copy_compile_commands()
  local compile_commands = utils.get_build_dir() / 'compile_commands.json'
  local destination = Path:new(vim.fn.getcwd(), 'compile_commands.json')
  destination:rm()
  compile_commands:copy({ destination = destination.filename })
end

function utils.copy_folder(folder, destination)
  destination:mkdir()
  for _, entry in ipairs(scandir.scan_dir(folder.filename, { depth = 1, add_dirs = true })) do
    local target_entry = destination / entry:sub(#folder.filename + 2)
    local source_entry = Path:new(entry)
    if source_entry:is_file() then
      if not source_entry:copy({ destination = target_entry.filename }) then
        error('Unable to copy ' .. target_entry)
      end
    else
      utils.copy_folder(folder, target_entry)
    end
  end
end

function utils.check_debugging_build_type(parameters)
  local buildType = parameters['buildType']
  if buildType ~= 'Debug' and buildType ~= 'RelWithDebInfo' then
    utils.notify('For debugging you need to use Debug or RelWithDebInfo, but currently your build type is ' .. buildType, vim.log.levels.ERROR)
    return false
  end
  return true
end

function utils.run(cmd, args, opts)
  vim.fn.setqflist({}, ' ', { title = cmd .. ' ' .. table.concat(args, ' ') })
  vim.api.nvim_command('copen ' .. config.quickfix_height)
  vim.api.nvim_command('wincmd p')

  utils.last_job = Job:new({
    command = cmd,
    args = args,
    cwd = opts.cwd,
    on_stdout = print_output,
    on_stderr = print_output,
    on_exit = vim.schedule_wrap(function(_, exit_code)
      vim.fn.setqflist({}, 'a', { lines = { 'Exited with code ' .. exit_code } })
      if exit_code == 0 and opts.on_success then
        opts.on_success()
      end
    end),
  })

  utils.last_job:start()
  return utils.last_job
end

return utils
