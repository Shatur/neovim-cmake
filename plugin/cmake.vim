if exists('g:loaded_cmake_projects')
  finish
endif
let g:loaded_cmake_projects = v:true

let g:cmake_parameters_file = get(g:, 'cmake_parameters_file', 'vim.json')
let g:cmake_samples_path = get(g:, 'cmake_samples_path', expand('<sfile>:p:h:h') .. '/samples/')
let g:default_cmake_projects_path = get(g:, 'default_cmake_projects_path', expand('~/Projects'))
let g:cmake_asyncrun_options = get(g:, 'cmake_asyncrun_options', {'save': 2})
let g:cmake_target_asyncrun_options = get(g:, 'cmake_target_asyncrun_options', {})

function! s:match_commands(arg, line, pos)
  return luaeval('require("cmake.commands").match_commands("' .. a:arg .. '")')
endfunction

command! -nargs=* -complete=customlist,s:match_commands CMake lua require('cmake.commands').run_command(<f-args>)
