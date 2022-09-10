# Neovim CMake

**This plugin has been deprecated in favor of [neovim-tasks](https://github.com/Shatur/neovim-tasks)**. I realized that having separate plugins for each build system is inconvenient, so I decided to write a general purpose plugin that could support support any build system. If you don't like this idea don't worry, there is a maintained hard fork called [cmake-tools.nvim](https://github.com/Civitasv/cmake-tools.nvim) with some additional features.

A Neovim 0.7+ plugin that uses [cmake-file-api](https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html#codemodel-version-2) to provide integration with building, running and debugging projects with output to quickfix.

## Dependencies

- Necessary
  - [cmake](https://cmake.org) for building and reading project information.
  - [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for internal helpers.
- Optional
  - [nvim-dap](https://github.com/mfussenegger/nvim-dap) - for debugging.

## Commands

Use the command `:CMake` with one of the following arguments:

| Argument               | Description                                                                                                                                                                                                                                 |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `configure ...`        | Configure project. It uses `g:cmake_build_dir` as a build folder. It will also generate `compile_commands.json` and symlink it to the project directory. Additional arguments will be passed to CMake. Example: `CMake configure -G Ninja`. |
| `build ...`            | Compile selected target (via `--build`). Additional arguments will be passed to CMake.                                                                                                                                                      |
| `build_all ...`        | Same as above, but will build `all` rule.                                                                                                                                                                                                   |
| `run ...`              | Run selected target. Additional arguments will be passed to the target being launched.                                                                                                                                                      |
| `debug ...`            | Run debugging on selected target. Additional arguments will be passed to the target being launched.                                                                                                                                         |
| `clean ...`            | Execute `clear` target. Additional arguments will be passed to CMake.                                                                                                                                                                       |
| `build_and_run ...`    | Execute `CMake build` and, if build successful, then `CMake run`. Additional arguments will be passed to CMake.                                                                                                                             |
| `build_and_debug ...`  | Execute `CMake build` and, if build successful, then `CMake debug`. Additional arguments will be passed to CMake.                                                                                                                           |
| `set_target_arguments` | Set arguments for running / debugging target.                                                                                                                                                                                               |
| `clear_cache`          | Remove `CMakeCache.txt` file from the build directory.                                                                                                                                                                                      |
| `open_build_dir`       | Open current build folder via `xdg-open` (Linux) or `start` (Windows).                                                                                                                                                                      |
| `select_build_type`    | Select build type (Release, Debug, etc.).                                                                                                                                                                                                   |
| `select_dap_config`    | Select a project sepecific DAP configuration. You can configure the options in `require('cmake').setup({ dap_configurations = { ... } })`                                                                                                   |
| `select_target`        | Select target for running / debugging.                                                                                                                                                                                                      |
| `create_project`       | Create new CMake project.                                                                                                                                                                                                                   |
| `cancel`               | Cancel current running CMake action like `build` or `run`.                                                                                                                                                                                  |

If no arguments are specified, then `configure` will be executed.

Also the corresponding Lua functions with the same names as the arguments are available from [`require('cmake')`](lua/cmake/init.lua).

Commands `select_build_type`, `select_target` and `create_project` use `vim.ui.select()`. To use your favorite picker like Telescope, consider installing [dressing.nvim](https://github.com/stevearc/dressing.nvim) or [telescope-ui-select.nvim](https://github.com/nvim-telescope/telescope-ui-select.nvim).

## Simple usage example

1. Create a new project (`:CMake create_project`) or open folder with an existing.
2. Configure project (`:CMake configure`, you can pass any additional CMake arguments) to create build folder and get targets information.
3. Select target to execute (`:CMake select_target`).
4. Set target arguments (`:CMake set_target_arguments`, they will be added automatically for running and debugging).
5. Build and run (`:CMake build_and_run`) or build and debug (`:CMake build_and_debug`) to execute the selected target. You can pass additional arguments to these commands, which will be temporarily added to the arguments from 4.

## Configuration

To configure the plugin, you can call `require('cmake').setup(values)`, where `values` is a dictionary with the parameters you want to override. Here are the defaults:

```lua
local Path = require('plenary.path')
require('cmake').setup({
  cmake_executable = 'cmake', -- CMake executable to run.
  save_before_build = true, -- Save all buffers before building.
  parameters_file = 'neovim.json', -- JSON file to store information about selected target, run arguments and build type.
  default_parameters = { args = {}, build_type = 'Debug' }, -- The default values in `parameters_file`. Can also optionally contain `run_dir` with the working directory for applications.
  build_dir = tostring(Path:new('{cwd}', 'build', '{os}-{build_type}')), -- Build directory. The expressions `{cwd}`, `{os}` and `{build_type}` will be expanded with the corresponding text values. Could be a function that return the path to the build directory.
  samples_path = tostring(script_path:parent():parent():parent() / 'samples'), -- Folder with samples. `samples` folder from the plugin directory is used by default.
  default_projects_path = tostring(Path:new(vim.loop.os_homedir(), 'Projects')), -- Default folder for creating project.
  configure_args = { '-D', 'CMAKE_EXPORT_COMPILE_COMMANDS=1' }, -- Default arguments that will be always passed at cmake configure step. By default tells cmake to generate `compile_commands.json`.
  build_args = {}, -- Default arguments that will be always passed at cmake build step.
  on_build_output = nil, -- Callback that will be called each time data is received by the current process. Accepts the received data as an argument.
  quickfix = {
    pos = 'botright', -- Where to open quickfix
    height = 10, -- Height of the opened quickfix.
    only_on_error = false, -- Open quickfix window only if target build failed.
  },
  copy_compile_commands = true, -- Copy compile_commands.json to current working directory.
  dap_configurations = { -- Table of different DAP configurations.
    lldb_vscode = { type = 'lldb', request = 'launch' },
    cppdbg_vscode = { type = 'cppdbg', request = 'launch' },
  },
  dap_configuration = 'lldb_vscode', -- DAP configuration to use if the projects `parameters_file` does not specify one.
  dap_open_command = function(...) require('dap').repl.open(...) end, -- Command to run after starting DAP session. You can set it to `false` if you don't want to open anything or `require('dapui').open` if you are using https://github.com/rcarriga/nvim-dap-ui
})
```

The mentioned `parameters_file` will be created for every project using `default_parameters` as defaults:

```jsonc
{
  "args": {"target_name": ["arg1", "arg2"]}, // A dictionary with target names and their arguments specified as an array.
  "current_target": "target_name", // Current target name.
  "build_type": "Debug", // Current build type, can be Debug, Release, RelWithDebInfo or MinSizeRel.
  "run_dir": "build/my_folder", // Default working directory for targets. Can be absolute or relative to the current Neovim working directory. By default is missing, in this case current target directory will be used.
  "dap_configuration": "cppdbg_vscode" // A string specifying a specific dap configuration to use for this project. If absent then the `dap_configuration` from `require('cmake').setup` will be used, which is the default behaviour.
}
```

Usually you don't need to edit it manually, you can set its values using the `:CMake <subcommand>` commands.

### CodeLLDB DAP configuration example

```lua
require('cmake').setup({
  dap_configuration = {
    type = 'codelldb',
    request = 'launch',
    stopOnEntry = false,
    runInTerminal = false,
  }
})
```

### Advanced usage examples

```lua
progress = ""  -- can be displayed in statusline, updated in on_build_output

require('cmake').setup({
  quickfix = {
    only_on_error = true,
  },
  on_build_output = function(lines)
    -- Get only last line
    local match = string.match(lines[#lines], "(%[.*%])")
    if match then
      progress = string.gsub(match, "%%", "%%%%")
    end
  end
})
```

Additionally all `cmake` module functions that runs something return `Plenary.job`, so one can also set callbacks:

```lua
function cmake_build()
  local job = require('cmake').build()
  if job then
    job:after(vim.schedule_wrap(
      function(_, exit_code)
        if exit_code == 0 then
          vim.notify("Target was built successfully", vim.log.levels.INFO, { title = 'CMake' })
        else
          vim.notify("Target build failed", vim.log.levels.ERROR, { title = 'CMake' })
        end
      end
    ))
  end
end
```
