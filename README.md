# Neovim CMake

A Neovim plugin that use [cmake-file-api](https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html#codemodel-version-2) to provide integration with building, running and debugging projects.

## Dependencies

- [cmake](https://cmake.org) for building and reading project information.
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) to select targets, build types and samples.
- [AsyncRun](https://github.com/skywind3000/asyncrun.vim) to run all tasks asynchronously.
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) for debugging.

## Setup

To make CMake telescope pickers available you should call `require('telescope').load_extension('cmake')`.

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
| `clear_cache`          | Removes `CMakeCache.txt` file from the build directory.                                                                                                                                                                                     |
| `open_build_dir`       | Open current build folder via `xdg-open` (Linux) or `start` (Windows).                                                                                                                                                                      |

If no arguments are specified, then `configure` will be executed.

Also the corresponding Lua functions with the same names as the arguments are available from [require('cmake')](lua/cmake/init.lua).

Use `:Telescope cmake` with one for the following arguments:

| Argument            | Description                               |
| ------------------- | ----------------------------------------- |
| `select_build_type` | Select build type (Release, Debug, etc.). |
| `select_target`     | Select target for running / debugging.    |
| `create_project`    | Create new CMake project.                 |

Also the corresponding Lua functions with the same names as the arguments are available from [require('telescope').extensions.cmake](lua/telescope/_extensions/cmake.lua).

## Parameters

| Variable                          | Default value                           | Description                                                                                                                                                                                                                    |
| --------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `g:loaded_cmake`                  | `v:true`                                | Set this value to `v:false` to disable plugin loading.                                                                                                                                                                         |
| `g:cmake_parameters_file`         | `'neovim.json'`                         | JSON file to store information about selected target, run arguments and build type. `vim.json` (in project directory) by default.                                                                                              |
| `g:cmake_build_dir`               | `{cwd}/build/{os}-{build_type}`         | Build directory. The expressions `{cwd}`, `{os}` and `{build_type}` will be expanded with the corresponding text values.                                                                                                       |
| `g:cmake_samples_path`            | `expand('<sfile>:p:h:h') . '/samples/'` | Folder with samples. `samples` folder from the plugin directory is used by default.                                                                                                                                            |
| `g:default_cmake_projects_path`   | `expand('~/Projects')`                  | Default folder for creating project.                                                                                                                                                                                           |
| `g:cmake_configure_arguments`     | `'-D CMAKE_EXPORT_COMPILE_COMMANDS=1'`  | Default arguments that will be always passed at cmake configure step. By default tells cmake to generate `compile_commands.json`. Example: `vim.g.cmake_configure_arguments = vim.g.cmake_configure_arguments .. ' -G Ninja'`. |
| `g:cmake_build_arguments`         | `''`                                    | Default arguments that will be always passed at cmake build step. Example: `vim.g.cmake_build_arguments = '-j8'`.                                                                                                              |
| `g:cmake_asyncrun_options`        | `{'save': 2}`                           | AsyncRun [options](https://github.com/skywind3000/asyncrun.vim#manual) that will be passed on cmake execution.                                                                                                                 |
| `g:cmake_target_asyncrun_options` | `{}`                                    | AsyncRun [options](https://github.com/skywind3000/asyncrun.vim#manual) that will be passed on target execution.                                                                                                                |
| `g:cmake_dap_configuration`       | `{'type': 'cpp', 'request': 'launch'}`  | Default DAP configuration that works with `lldb-vscode`                                                                                                                                                                        |
| `g:cmake_dap_repl_open`           | `v:true`                                | Set this value to `v:false` to stop DAP REPL from opening automatically                                                                                                                                                        |

The user may also specify the default path to run the targets from by defining it in the `g:cmake_parameters_file` in the base directory of the project, (i.e):

```json
{
  "arguments": [],
  "currentTarget": "target",
  "buildType": "Debug",
  "run_dir": "path/to/directory/"
}
```

## Simple usage example

1. Create a new project (`:Telescope cmake create_project`) or open an existing.
2. Configure project (`:CMake configure`) to create build folder and get targets information
3. Select target to execute (`:Telescope select_target`).
4. Build and run (`:CMake build_and_run`)

## MSVC x64 configuration example

Here we defined a [command modifier](https://github.com/skywind3000/asyncrun.vim#command-modifier) and specified it in `g:cmake_asyncrun_options`:

```lua
vim.g.asyncrun_program = vim.empty_dict()
-- Should be done via cmd in Lua because lambda cannot be stored in a variable (https://github.com/nanotee/nvim-lua-guide#conversion-is-not-always-possible)
vim.api.nvim_command("let g:asyncrun_program.vcvars64 = { opts -> '\"C:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Auxiliary/Build/vcvars64.bat\" && ' .. opts.cmd }")
vim.g.cmake_asyncrun_options = vim.tbl_extend('force', vim.g.cmake_asyncrun_options, {program = 'vcvars64'})
```

## DAP configuration example

You can customize the DAP configuration via `g:cmake_dap_configuration`, `type` key and `request` key must be assigned.

Here is an example of `CodeLLDB` customization:

```lua
vim.g.cmake_dap_configuration = {
  type = 'codelldb',
  request = 'launch',
  stopOnEntry = false,
  runInTerminal = false,
}
```
