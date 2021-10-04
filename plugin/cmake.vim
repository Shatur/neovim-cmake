if exists('g:loaded_cmake')
  finish
endif
let g:loaded_cmake = v:true

let g:cmake_parameters_file = get(g:, 'cmake_parameters_file', 'neovim.json')
let g:cmake_build_dir = get(g:, 'cmake_build_dir', '{cwd}/build/{os}-{build_type}')
let g:cmake_samples_path = get(g:, 'cmake_samples_path', expand('<sfile>:p:h:h') .. '/samples/')
let g:default_cmake_projects_path = get(g:, 'default_cmake_projects_path', expand('~/Projects'))
let g:cmake_configure_arguments = get(g:, 'cmake_configure_arguments', '-D CMAKE_EXPORT_COMPILE_COMMANDS=1')
let g:cmake_build_arguments = get(g:, 'cmake_build_arguments', '')
let g:cmake_asyncrun_options = get(g:, 'cmake_asyncrun_options', {'save': 2})
let g:cmake_target_asyncrun_options = get(g:, 'cmake_target_asyncrun_options', {})
let g:cmake_dap_configuration  = get(g:, 'cmake_dap_configuration', {'type': 'cpp', 'request': 'launch'})

function! s:match_commands(arg, line, pos)
  return luaeval('require("cmake.commands").match_commands("' .. a:arg .. '")')
endfunction

command! -nargs=* -complete=customlist,s:match_commands CMake lua require('cmake.commands').run_command(<f-args>)
