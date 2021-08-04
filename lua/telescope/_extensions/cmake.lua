local telescope = require('telescope')
local actions = require('telescope.actions')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')
local utils = require('cmake.utils')

local function select_build_type(opts)
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
        parameters['buildType'] = actions.get_selected_entry(prompt_bufnr).display
        utils.set_parameters(parameters)
      end

      actions.select_default:replace(select)
      return true
    end,
  }):find()
end

local function select_target(opts)
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
        parameters['currentTarget'] = actions.get_selected_entry(prompt_bufnr).value
        utils.set_parameters(parameters)
      end

      actions.select_default:replace(select)
      return true
    end,
  }):find()
end

local function create_project()
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

  local samples = vim.fn.map(vim.fn.readdir(vim.g.cmake_samples_path), 'fnamemodify(v:val, ":t")')
  pickers.new({}, {
    prompt_title = 'Select sample',
    finder = finders.new_table({
      results = samples,
    }),
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr)
      local select = function()
        actions.close(prompt_bufnr)
        utils.copy_folder(vim.g.cmake_samples_path .. actions.get_selected_entry(prompt_bufnr).display, project_path)
        vim.cmd('edit ' .. project_path .. '/CMakeLists.txt')
        vim.cmd('cd %:h')
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
