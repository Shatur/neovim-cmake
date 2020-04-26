if exists('g:cmake_loaded') || !exists(':AsyncRun') || !exists(':FZF')
  finish
endif
let g:cmake_loaded = v:true
let g:cmake_build_all = v:true
let g:parameters_file = 'vim.json'

command! CMakeConfigure call cmake#configure()
command! CMakeBuild call cmake#build()
command! CMakeRun call cmake#run()
command! CMakeDebug call cmake#debug()
command! CMakeClean call cmake#clean()

command! CMakeSelectBuildType call cmake#select_build_type()
command! CMakeSelectTarget call cmake#select_target()

command! CMakeSetTargetArguments call cmake#set_target_arguments()
command! CMakeToggleBuildAll call cmake#toogle_build_all()
