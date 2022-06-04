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
      utils.copy_folder(source_entry, target_entry)
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
    on_exit = vim.schedule_wrap(function(_, code, signal)
      append_to_quickfix('Exited with code ' .. (signal == 0 and code or 128 + signal))
      if code == 0 and signal == 0 then
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

local function create_terminal_buf(terminal_win_cmd)
  local cur_win = vim.api.nvim_get_current_win()
  vim.api.nvim_command(terminal_win_cmd)
  local bufnr = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(cur_win)
  return bufnr, win
end

local terminal_buf

function utils.run_in_terminal(cmd, args, opts)
  local cur_buf = vim.api.nvim_get_current_buf()

  -- TODO: We need to always delete??? otherwise click ZZ will hide it
  if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
    vim.api.nvim_buf_set_option(terminal_buf, 'modified', false)
  else
    local terminal_win
    terminal_buf, terminal_win = create_terminal_buf('belowright new')
    if terminal_win then
      vim.wo[terminal_win].number = false
      vim.wo[terminal_win].relativenumber = false
      vim.wo[terminal_win].signcolumn = 'no'
    end
    vim.api.nvim_win_set_height(terminal_win, config.quickfix_height)
    vim.api.nvim_buf_set_name(terminal_buf, '[neovim-cmake-terminal]')
  end
  local ok, path = pcall(vim.api.nvim_buf_get_option, cur_buf, 'path')
  if ok then
    vim.api.nvim_buf_set_option(terminal_buf, 'path', path)
  end
  local jobid

  local chan = vim.api.nvim_open_term(terminal_buf, {
    on_input = function(_, _, _, data)
      pcall(vim.api.nvim_chan_send, jobid, data)
    end,
  })

  jobid = vim.fn.jobstart(cmd, {
    args = args,
    cwd = opts.cwd,
    pty = true,
    on_stdout = function(_, data)
      vim.api.nvim_chan_send(chan, table.concat(data, '\n'))
    end,
    on_exit = function(_, exit_code)
      vim.api.nvim_chan_send(chan, '\r\n[Process exited ' .. tostring(exit_code) .. ']')
      vim.api.nvim_buf_set_keymap(terminal_buf, 't', '<CR>', '<cmd>bd!<CR>', { noremap = true, silent = true })
    end,
  })

  local focus_terminal = true
  if focus_terminal then
    for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_buf(win) == terminal_buf then
        vim.api.nvim_set_current_win(win)
        break
      end
    end
  end
  if jobid == 0 or jobid == -1 then
    vim.notify('Could not spawn terminal', jobid)
  else
    -- TODO: Fix
    vim.notify('Hola')
  end
end

function utils.ensure_no_job_active()
  if not utils.last_job or utils.last_job.is_shutdown then
    return true
  end
  utils.notify('Another job is currently running: ' .. utils.last_job.command, vim.log.levels.ERROR)
  return false
end

return utils
