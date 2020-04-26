# Vim Cmake Projects

A Vim plugin that use [cmake-file-api](https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html#codemodel-version-2) to provide integration with building, running and debugging projects.

## Dependencies

- [cmake](https://cmake.org) for building and reading project information.
- [fzf](https://github.com/skywind3000/asyncrun.vim) to select targets and build types.
- [AsyncRun](https://github.com/skywind3000/asyncrun.vim) to run all tasks asynchronously.

## Commands

| Command                 | Description                                                                                                                                                                             |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CMakeConfigure          | Configure project. It uses `../<current directory name>-<build type>-build` as build folder. It will also generate `compile_commands.json` and add it symlink to the project directory. |
| CMakeSelectBuildType    | Select build type (Release, Debug, etc.).                                                                                                                                               |
| CMakeBuild              | Run compilation. It will compile the whole project if `g:cmake_build_all` is set to `v:true`, otherwise will build only selected target.                                                |
| CMakeSelectTarget       | Select target for running / debugging.                                                                                                                                                  |
| CMakeSetTargetArguments | Set arguments for running / debugging target.                                                                                                                                           |
| CMakeRun                | Run selected target.                                                                                                                                                                    |
| CMakeToggleBuildAll     | Convenient toggling of `g:cmake_build_all` variable.                                                                                                                                    |

## Parameters

| Variable            | Description                                                                                                                       |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `g:cmake_loaded`    | Enable plugin loading. `v:true` by default.                                                                                       |
| `g:cmake_build_all` | Build all project if enabled. Otherwise build only selected target. `v:true` by default.                                          |
| `g:parameters_file` | JSON file to store information about selected target, run arguments and build type. `vim.json` (in project directory) by default. |
