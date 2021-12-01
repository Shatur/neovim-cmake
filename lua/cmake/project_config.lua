local config = require('cmake.config')
local os = require('ffi').os:lower()
local utils = require('cmake.utils')
local Path = require('plenary.path')
local ProjectConfig = {}
ProjectConfig.__index = ProjectConfig

local json_defaults = {
  args = {},
  build_type = 'Debug',
}

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

function ProjectConfig.new()
  local project_config = {}
  local parameters_file = Path:new(config.parameters_file)
  if parameters_file:is_file() then
    project_config.json = vim.fn.json_decode(parameters_file:read())
  else
    project_config.json = {}
  end
  project_config.json = vim.tbl_extend('keep', project_config.json, json_defaults)
  return setmetatable(project_config, ProjectConfig)
end

function ProjectConfig:write()
  local parameters_file = Path:new(config.parameters_file)
  parameters_file:write(vim.fn.json_encode(self.json), 'w')
end

function ProjectConfig:get_build_dir()
  -- Return cached result
  if self.build_dir then
    return self.build_dir
  end

  self.build_dir = config.build_dir
  self.build_dir = self.build_dir:gsub('{cwd}', vim.loop.cwd())
  self.build_dir = self.build_dir:gsub('{os}', os)
  self.build_dir = self.build_dir:gsub('{build_type}', self.json.build_type:lower())
  self.build_dir = Path:new(self.build_dir)
  return self.build_dir
end

function ProjectConfig:get_reply_dir()
  -- Return cached result
  if self.reply_dir then
    return self.reply_dir
  end

  self.reply_dir = self:get_build_dir() / '.cmake' / 'api' / 'v1' / 'reply'
  return self.reply_dir
end

function ProjectConfig:get_codemodel_targets()
  local codemodel = Path:new(vim.fn.globpath(self:get_reply_dir().filename, 'codemodel*'))
  local codemodel_json = vim.fn.json_decode(codemodel:read())
  return codemodel_json['configurations'][1]['targets']
end

function ProjectConfig:get_target_info(codemodel_target)
  return vim.fn.json_decode((self:get_reply_dir() / codemodel_target['jsonFile']):read())
end

-- Tell CMake to generate codemodel
function ProjectConfig:make_query_files()
  local query_dir = self:get_build_dir() / '.cmake' / 'api' / 'v1' / 'query'
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

function ProjectConfig:get_current_executable_info()
  if not self:get_build_dir():is_dir() then
    utils.notify('You need to configure first', vim.log.levels.ERROR)
    return nil
  end

  if not self.json.current_target then
    utils.notify('You need to select target first', vim.log.levels.ERROR)
    return nil
  end

  for _, target in ipairs(self:get_codemodel_targets()) do
    if self.json.current_target == target['name'] then
      local target_info = self:get_target_info(target)
      if target_info['type'] ~= 'EXECUTABLE' then
        utils.notify('Specified target is not executable: ' .. self.json.current_target, vim.log.levels.ERROR)
        return nil
      end
      return target_info
    end
  end

  utils.notify('Unable to find the following target: ' .. self.json.current_target, vim.log.levels.ERROR)
  return nil
end

function ProjectConfig:get_current_target()
  local target_info = self:get_current_executable_info()
  if not target_info then
    return nil
  end

  local target = self:get_build_dir() / target_info['artifacts'][1]['path']
  if not target:is_file() then
    utils.notify('Selected target is not built: ' .. target.filename, vim.log.levels.ERROR)
    return nil
  end

  local target_dir = self.json.run_dir
  if target_dir == nil then
    target_dir = target:parent()
  end
  local target_args = split_args(self.json.args[target_info['name']]) or {}
  return target_dir, target, target_args
end

function ProjectConfig:validate_for_debugging()
  local build_type = self.json.build_type
  if build_type ~= 'Debug' and build_type ~= 'RelWithDebInfo' then
    utils.notify('For debugging you need to use Debug or RelWithDebInfo, but currently your build type is ' .. build_type, vim.log.levels.ERROR)
    return false
  end
  return true
end

function ProjectConfig:copy_compile_commands()
  local compile_commands = self:get_build_dir() / 'compile_commands.json'
  local destination = Path:new(vim.loop.cwd(), 'compile_commands.json')
  destination:rm()
  compile_commands:copy({ destination = destination.filename })
end

return ProjectConfig
