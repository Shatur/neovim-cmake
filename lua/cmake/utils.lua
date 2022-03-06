local Job = require('plenary.job')
local Path = require('plenary.path')
local config = require('cmake.config')
local scandir = require('plenary.scandir')
local utils = {}

local function append_to_quickfix(error, data)
  local line = error and error or data
  vim.fn.setqflist({}, 'a', { lines = { line } })
  -- Scrolls the quickfix buffer if not active
  if vim.bo.buftype ~= 'quickfix' then
    vim.api.nvim_command('cbottom')
  end
  if config.on_build_output then
    config.on_build_output(line)
  end
end

local function show_quickfix()
  vim.api.nvim_command('copen ' .. config.quickfix_height)
  vim.api.nvim_command('wincmd p')
end

function utils.notify(msg, log_level)
  vim.notify(msg, log_level, { title = 'CMake' })
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

function utils.run(cmd, args, opts)
  vim.fn.setqflist({}, ' ', { title = cmd .. ' ' .. table.concat(args, ' ') })
  opts.open_quickfix = vim.F.if_nil(opts.open_quickfix, not config.quickfix_only_on_error)
  if opts.open_quickfix then
    show_quickfix()
  end

  utils.last_job = Job:new({
    command = cmd,
    args = args,
    cwd = opts.cwd,
    on_stdout = vim.schedule_wrap(append_to_quickfix),
    on_stderr = vim.schedule_wrap(append_to_quickfix),
    on_exit = vim.schedule_wrap(function(_, exit_code)
      append_to_quickfix('Exited with code ' .. exit_code)
      if exit_code == 0 then
        if opts.on_success then
          opts.on_success()
        end
      elseif not opts.show_quickfix then
        show_quickfix()
        vim.api.nvim_command('cbottom')
      end
    end),
  })

  utils.last_job:start()
  return utils.last_job
end

function utils.ensure_no_job_active()
  if not utils.last_job or utils.last_job.is_shutdown then
    return true
  end
  utils.notify('Another job is currently running: ' .. utils.last_job.command, vim.log.levels.ERROR)
  return false
end

return utils
