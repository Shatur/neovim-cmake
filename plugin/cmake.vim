if exists('g:loaded_cmake_projects') || !exists(':AsyncRun') || !exists(':FZF')
  finish
endif
let g:loaded_cmake_projects = get(g:, 'loaded_cmake_projects', v:true)
let g:cmake_build_all = get(g:, 'cmake_build_all', v:true)
let g:cmake_autosave = get(g:, 'cmake_autosave', v:true)
let g:cmake_parameters_file = get(g:, 'cmake_parameters_file', 'vim.json')
let g:cmake_samples_path = get(g:, 'cmake_samples_path', expand('<sfile>:p:h:h') . '/samples/')
let g:default_cmake_projects_path = get(g:, 'default_cmake_projects_path', expand('~/Projects'))

command! -nargs=* -complete=shellcmd CMakeConfigure call cmake#configure(<q-args>)
command! -nargs=* -complete=shellcmd CMakeBuild call cmake#build(<q-args>)

command! CMakeRun call cmake#run()
command! CMakeDebug call cmake#debug()
command! CMakeClean call cmake#clean()

command! -nargs=* -complete=shellcmd CMakeBuildAndRun call cmake#build_and_run(<q-args>)
command! -nargs=* -complete=shellcmd CMakeBuildAndDebug call cmake#build_and_debug(<q-args>)

command! CMakeSelectBuildType call cmake#select_build_type()
command! CMakeSelectTarget call cmake#select_target()
command! CMakeCreateProject call cmake#create_project()

command! CMakeSetTargetArguments call cmake#set_target_arguments()
command! CMakeToggleBuildAll call cmake#toogle_build_all()
command! CMakeOpenBuildDir call cmake#open_build_dir()
