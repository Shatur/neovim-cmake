# Vim Cmake Projects

A Vim plugin that use [cmake-file-api](https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html#codemodel-version-2) to provide integration with building, running and debugging projects.

## Dependencies

- [cmake](https://cmake.org) for building and reading project information.
- [fzf](https://github.com/junegunn/fzf) to select targets and build types.
- [AsyncRun](https://github.com/skywind3000/asyncrun.vim) to run all tasks asynchronously.

## Commands

| Function                                      | Command                 | Description                                                                                                                                                                                                                                                                                                             |
| --------------------------------------------- | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cmake#get_build_dir()`                       |                         | Returns current build directory. Can be useful for scripting.                                                                                                                                                                                                                                                           |
| `cmake#configure(additional_arguments)`       | CMakeConfigure          | Configure project. It uses `../<current directory name>-<build type>-build` as a build folder. It will also generate `compile_commands.json` and add it symlink to the project directory. You can pass additional arguments that will be passed to `cmake` command. For example, you can use `CMakeConfigure -G Ninja`. |
| `cmake#build(additional_arguments)`           | CMakeBuild              | Run compilation. It will compile the whole project if `g:cmake_build_all` is set to `v:true`, otherwise will build only selected target. Can accept additional arguments as in `CMakeConfigure`.                                                                                                                        |
| `cmake#run()`                                 | CMakeRun                | Run selected target.                                                                                                                                                                                                                                                                                                    |
| `cmake#debug()`                               | CMakeDebug              | Run `:Termdebug` on selected target.                                                                                                                                                                                                                                                                                    |
| `cmake#clean()`                               | CMakeClear              | Execute `clear` target.                                                                                                                                                                                                                                                                                                 |
| `cmake#build_and_run(additional_arguments)`   | CMakeBuildAndRun        | Execute `CMakeBuild` and, if build successful, then `CMakeRun`.                                                                                                                                                                                                                                                         |
| `cmake#build_and_debug(additional_arguments)` | CMakeBuildAndDebug      | Execute `CMakeBuild` and, if build successful, then `CMakeDebug`.                                                                                                                                                                                                                                                       |  |
| `cmake#select_build_type()`                   | CMakeSelectBuildType    | Select build type (Release, Debug, etc.).                                                                                                                                                                                                                                                                               |
| `cmake#select_target()`                       | CMakeSelectTarget       | Select target for running / debugging.                                                                                                                                                                                                                                                                                  |
| `cmake#create_project()`                      | CMakeCreateProject      | Create new CMake project.                                                                                                                                                                                                                                                                                               |
| `cmake#set_target_arguments()`                | CMakeSetTargetArguments | Set arguments for running / debugging target.                                                                                                                                                                                                                                                                           |
| `cmake#toogle_build_all()`                    | CMakeToggleBuildAll     | Convenient toggling of `g:cmake_build_all` variable.                                                                                                                                                                                                                                                                    |
| `cmake#open_build_dir()`                      | CMakeOpenBuildDir       | Open current build folder via `xdg-open` (Linux) or `start` (Windows).                                                                                                                                                                                                                                                  |

## Parameters

| Variable                        | Default value                           | Description                                                                                                                       |
| ------------------------------- | --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `g:loaded_cmake_projects`       | `v:true`                                | Set this value to `v:false` to disable plugin loading.                                                                            |
| `g:cmake_build_all`             | `v:true`                                | Build all project if enabled. Otherwise build only selected target.                                                               |
| `g:cmake_parameters_file`       | `'vim.json'`                            | JSON file to store information about selected target, run arguments and build type. `vim.json` (in project directory) by default. |
| `g:cmake_samples_path`          | `expand('<sfile>:p:h:h') . '/samples/'` | Folder with samples. `samples` folder from the plugin directory is used by default.                                               |
| `g:default_cmake_projects_path` | `expand('~/Projects')`                  | Default folder for creating project.                                                                                              |
| `g:cmake_configure_options`     | `{'save': 2}`                           | AsyncRun [options](https://github.com/skywind3000/asyncrun.vim#manual) that will be passed to the command during configuration.   |
| `g:cmake_build_options`         | `{'save': 2}`                           | AsyncRun [options](https://github.com/skywind3000/asyncrun.vim#manual) that will be passed to the command during build.           |
| `g:cmake_run_options`           | `{}`                                    | AsyncRun [options](https://github.com/skywind3000/asyncrun.vim#manual) that will be passed to the command during run.             |
| `g:cmake_clean_options`         | `{}`                                    | AsyncRun [options](https://github.com/skywind3000/asyncrun.vim#manual) that will be passed to the command during clean.           |

## Simple usage example

1. Create a new project (`:CMakeCreateProject`) or open an existing.
2. Configure project (`:CMakeConfigure`) to create build folder and get targets information
3. Select target to execute (`:CMakeSelectTarget`).
4. Build and run (`:CMakeBuildAndRun`)

[Here](https://github.com/Shatur95/neovim-config/blob/master/plugin/vim-cmake-projects.vim) is my configuration.
