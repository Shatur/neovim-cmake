# Vim Cmake Projects

A Vim plugin that use [cmake-file-api](https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html#codemodel-version-2) to provide integration with building, running and debugging projects.

## Dependencies

- [cmake](https://cmake.org) for building and reading project information.
- [fzf](https://github.com/skywind3000/asyncrun.vim) to select targets and build types.
- [AsyncRun](https://github.com/skywind3000/asyncrun.vim) to run all tasks asynchronously.

## Commands

| Command                 | Description                                                                                                                                                                                                                                                                                                             |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CMakeConfigure          | Configure project. It uses `../<current directory name>-<build type>-build` as a build folder. It will also generate `compile_commands.json` and add it symlink to the project directory. You can pass additional arguments that will be passed to `cmake` command. For example, you can use `CMakeConfigure -G Ninja`. |
| CMakeBuild              | Run compilation. It will compile the whole project if `g:cmake_build_all` is set to `v:true`, otherwise will build only selected target. Can accept additional arguments as in `CMakeConfigure`.                                                                                                                        |
| CMakeRun                | Run selected target.                                                                                                                                                                                                                                                                                                    |
| CMakeDebug              | Run `:Termdebug` on selected target.                                                                                                                                                                                                                                                                                    |
| CMakeClear              | Execute `clear` target.                                                                                                                                                                                                                                                                                                 |
| CMakeSelectBuildType    | Select build type (Release, Debug, etc.).                                                                                                                                                                                                                                                                               |
| CMakeSelectTarget       | Select target for running / debugging.                                                                                                                                                                                                                                                                                  |
| CMakeSetTargetArguments | Set arguments for running / debugging target.                                                                                                                                                                                                                                                                           |
| CMakeToggleBuildAll     | Convenient toggling of `g:cmake_build_all` variable.                                                                                                                                                                                                                                                                    |

## Parameters

| Variable                           | Description                                                                                                                       |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `g:cmake_loaded=v:true`            | Enable plugin loading.                                                                                                            |
| `g:cmake_build_all=v:true`         | Build all project if enabled. Otherwise build only selected target.                                                               |
| `g:cmake_save_before_build=v:true` | Save all files automatically before build.                                                                                        |
| `g:parameters_file='vim.json'`     | JSON file to store information about selected target, run arguments and build type. `vim.json` (in project directory) by default. |
