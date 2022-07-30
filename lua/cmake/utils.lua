local Job = require('plenary.job')
local Path = require('plenary.path')
local config = require('cmake.config')
local scandir = require('plenary.scandir')
local utils = {}

local function copy_compile_commands(source_folder)
  local filename = 'compile_commands.json'
  local source = source_folder / filename
  local destination = Path:new(vim.loop.cwd(), filename)
  source:copy({ destination = destination.filename })
end

local function append_to_quickfix(lines)
  vim.fn.setqflist({}, 'a', { lines = lines })
  -- Scrolls the quickfix buffer if not active
  if vim.bo.buftype ~= 'quickfix' then
    vim.api.nvim_command('cbottom')
  end
  if config.on_build_output then
    config.on_build_output(lines)
  end
end

local function show_quickfix()
  vim.api.nvim_command(config.quickfix.pos .. ' copen ' .. config.quickfix.height)
  vim.api.nvim_command('wincmd p')
end

local function read_to_quickfix()
  -- Modified from https://github.com/nvim-lua/plenary.nvim/blob/968a4b9afec0c633bc369662e78f8c5db0eba249/lua/plenary/job.lua#L287
  -- We use our own implementation to process data in chunks because
  -- default Plenary callback processes every line which is very slow for adding to quickfix.
  return coroutine.wrap(function(err, data, is_complete)
    -- We repeat forever as a coroutine so that we can keep calling this.
    local lines = {}
    local result_index = 1
    local result_line = nil
    local found_newline = nil

    while true do
      if data then
        data = data:gsub('\r', '')

        local processed_index = 1
        local data_length = #data + 1

        repeat
          local start = string.find(data, '\n', processed_index, true) or data_length
          local line = string.sub(data, processed_index, start - 1)
          found_newline = start ~= data_length

          -- Concat to last line if there was something there already.
          --    This happens when "data" is broken into chunks and sometimes
          --    the content is sent without any newlines.
          if result_line then
            result_line = result_line .. line

            -- Only put in a new line when we actually have new data to split.
            --    This is generally only false when we do end with a new line.
            --    It prevents putting in a "" to the end of the results.
          elseif start ~= processed_index or found_newline then
            result_line = line

            -- Otherwise, we don't need to do anything.
          end

          if found_newline then
            if not result_line then
              return vim.api.nvim_err_writeln('Broken data thing due to: ' .. tostring(result_line) .. ' ' .. tostring(data))
            end

            table.insert(lines, err and err or result_line)

            result_index = result_index + 1
            result_line = nil
          end

          processed_index = start + 1
        until not found_newline
      end

      if is_complete and not found_newline then
        table.insert(lines, err and err or result_line)
      end

      if #lines ~= 0 then
        -- Move lines to another variable and send them to quickfix
        local processed_lines = lines
        lines = {}
        vim.schedule(function() append_to_quickfix(processed_lines) end)
      end

      if data == nil or is_complete then
        return
      end

      err, data, is_complete = coroutine.yield()
    end
  end)
end

function utils.notify(msg, log_level) vim.notify(msg, log_level, { title = 'CMake' }) end

function utils.split_args(args)
  if not args then
    return {}
  end

  -- Handle table for compatibility with the previous version
  if type(args) == 'table' then
    return args
  end

  -- Split on spaces unless "in quotes"
  local splitted_args = vim.fn.split(args, [[\s\%(\%([^'"]*\(['"]\)[^'"]*\1\)*[^'"]*$\)\@=]])

  -- Remove quotes
  for i, arg in ipairs(splitted_args) do
    splitted_args[i] = arg:gsub('"', ''):gsub("'", '')
  end
  return splitted_args
end

function utils.join_args(args)
  if not args then
    return ''
  end

  -- Handle strings for compatibility with the previous version
  if type(args) == 'string' then
    return args
  end

  -- Add quotes if argument contain spaces
  for index, arg in ipairs(args) do
    if arg:find(' ') then
      args[index] = '"' .. arg .. '"'
    end
  end

  return table.concat(args, ' ')
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
      utils.copy_folder(source_entry, target_entry)
    end
  end
end

function utils.run(cmd, args, opts)
  if not utils.ensure_no_job_active() then
    return nil
  end

  if config.save_before_build and cmd == config.cmake_executable then
    vim.api.nvim_command('silent! wall')
  end

  vim.fn.setqflist({}, ' ', { title = cmd .. ' ' .. table.concat(args, ' ') })
  opts.force_quickfix = vim.F.if_nil(opts.force_quickfix, not config.quickfix.only_on_error)
  if opts.force_quickfix then
    show_quickfix()
  end

  utils.last_job = Job:new({
    command = cmd,
    args = args,
    cwd = opts.cwd,
    on_exit = vim.schedule_wrap(function(_, code, signal)
      append_to_quickfix({ 'Exited with code ' .. (signal == 0 and code or 128 + signal) })
      if code == 0 and signal == 0 then
        if config.copy_compile_commands and opts.copy_compile_commands_from then
          copy_compile_commands(opts.copy_compile_commands_from)
        end
      elseif not opts.force_quickfix then
        show_quickfix()
        vim.api.nvim_command('cbottom')
      end
    end),
  })

  utils.last_job:start()
  utils.last_job.stderr:read_start(read_to_quickfix())
  utils.last_job.stdout:read_start(read_to_quickfix())
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
