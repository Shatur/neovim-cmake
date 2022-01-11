if !has('nvim-0.6.0')
  echoerr 'neovim-cmake requires at least nvim-0.6.0'
  finish
end

if exists('g:loaded_cmake')
  finish
endif
let g:loaded_cmake = v:true

function! s:match_commands(arg, line, pos)
  return luaeval('require("cmake.commands").match_commands("' .. a:arg .. '")')
endfunction

command! -nargs=* -complete=customlist,s:match_commands CMake lua require('cmake.commands').run_command(<f-args>)
