if exists('g:loaded_cmake_projects') || !exists(':AsyncRun') || !exists(':FZF')
  finish
endif
let g:loaded_cmake_projects = get(g:, 'loaded_cmake_projects', v:true)
let g:cmake_parameters_file = get(g:, 'cmake_parameters_file', 'vim.json')
let g:cmake_samples_path = get(g:, 'cmake_samples_path', expand('<sfile>:p:h:h') . '/samples/')
let g:default_cmake_projects_path = get(g:, 'default_cmake_projects_path', expand('~/Projects'))
let g:cmake_configure_options = get(g:, 'cmake_configure_options', {'save': 2})
let g:cmake_build_options = get(g:, 'cmake_build_options', {'save': 2})
let g:cmake_run_options = get(g:, 'cmake_run_options', {})
let g:cmake_clean_options = get(g:, 'cmake_clean_options', {})

command! -nargs=* -complete=shellcmd CMakeConfigure call cmake#configure(<q-args>)
command! -nargs=* -complete=shellcmd CMakeBuild call cmake#build(<q-args>)
command! -nargs=* -complete=shellcmd CMakeBuildAll call cmake#build_all(<q-args>)

command! CMakeRun call cmake#run()
command! CMakeDebug call cmake#debug()
command! CMakeClean call cmake#clean()

command! -nargs=* -complete=shellcmd CMakeBuildAndRun call cmake#build_and_run(<q-args>)
command! -nargs=* -complete=shellcmd CMakeBuildAndDebug call cmake#build_and_debug(<q-args>)

command! CMakeSelectBuildType call cmake#select_build_type()
command! CMakeSelectTarget call cmake#select_target()
command! CMakeCreateProject call cmake#create_project()

command! CMakeSetTargetArguments call cmake#set_target_arguments()
command! CMakeOpenBuildDir call cmake#open_build_dir()
