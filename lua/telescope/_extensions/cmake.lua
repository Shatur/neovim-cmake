local telescope = require('telescope')
local actions = require('telescope.actions')
local state = require('telescope.actions.state')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')
local themes = require('telescope.themes')
local utils = require('cmake.utils')
local config = require('cmake.config')
local scandir = require('plenary.scandir')
local Path = require('plenary.path')

local function select_build_type(opts)
  -- Use dropdown theme by default
  opts = themes.get_dropdown(opts)

  local parameters = utils.get_parameters()
  local current_build_type = parameters['buildType']
  local types = {}
  for _, type in ipairs({ 'Debug', 'Release', 'RelWithDebInfo', 'MinSizeRel' }) do
    if type == current_build_type then
      table.insert(types, 1, type)
    else
      table.insert(types, type)
    end
  end

  pickers.new(opts, {
    prompt_title = 'Select build type',
    finder = finders.new_table({
      results = types,
    }),
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr)
      local select = function()
        actions.close(prompt_bufnr)
        parameters['buildType'] = state.get_selected_entry().display
        utils.set_parameters(parameters)
      end

      actions.select_default:replace(select)
      return true
    end,
  }):find()
end

local function select_target(opts)
  -- Use dropdown theme by default
  opts = themes.get_dropdown(opts)

  local parameters = utils.get_parameters()
  local build_dir = utils.get_build_dir(parameters)
  if not build_dir:is_dir() then
    utils.notify('You need to configure first', vim.log.levels.ERROR)
    return
  end

  local targets = {}
  local current_target = parameters['currentTarget']
  local reply_dir = utils.get_reply_dir(build_dir)
  for _, target in ipairs(utils.get_codemodel_targets(reply_dir)) do
    local target_info = utils.get_target_info(reply_dir, target)
    local target_name = target_info['name']
    if target_name:find('_autogen') == nil then
      local target_type = target_info['type']
      if target_name == current_target then
        table.insert(targets, 1, { name = target_name, type = target_type:lower():gsub('_', ' ') })
      else
        table.insert(targets, { name = target_name, type = target_type:lower():gsub('_', ' ') })
      end
    end
  end

  pickers.new(opts, {
    prompt_title = 'Select target',
    finder = finders.new_table({
      results = targets,
      entry_maker = function(entry)
        return {
          value = entry.name,
          display = entry.name .. ' (' .. entry.type .. ')',
          ordinal = entry.name .. ' (' .. entry.type .. ')',
        }
      end,
    }),
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr)
      local select = function()
        actions.close(prompt_bufnr)
        parameters['currentTarget'] = state.get_selected_entry().value
        utils.set_parameters(parameters)
      end

      actions.select_default:replace(select)
      return true
    end,
  }):find()
end

local function create_project(opts)
  -- Use dropdown theme by default
  opts = themes.get_dropdown(opts)

  pickers.new(opts, {
    prompt_title = 'Select sample',
    finder = finders.new_table({
      results = vim.fn.map(scandir.scan_dir(tostring(config.samples_path), { depth = 1, only_dirs = true }), 'fnamemodify(v:val, ":t")'),
    }),
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr)
      local select = function()
        actions.close(prompt_bufnr)

        local project_name = vim.fn.input('Project name: ')
        if #project_name == 0 then
          utils.notify('Project name cannot be empty', vim.log.levels.ERROR)
          return
        end

        local project_location = vim.fn.input('Create in: ', tostring(config.default_projects_path), 'file')
        if #project_location == 0 then
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

        utils.copy_folder(Path:new(config.samples_path) / state.get_selected_entry().display, project_path)
        vim.api.nvim_command('edit ' .. project_path:joinpath('CMakeLists.txt').filename)
        vim.api.nvim_command('cd %:h')
      end

      actions.select_default:replace(select)
      return true
    end,
  }):find()
end

return telescope.register_extension({
  exports = {
    select_build_type = select_build_type,
    select_target = select_target,
    create_project = create_project,
  },
})
