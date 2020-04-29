" Helpers
function! s:get_parameters() abort
  if !filereadable(g:parameters_file)
    return {'currentTarget': '', 'buildType': 'Debug', 'buildAll': v:true, 'arguments': {}}
  endif
  return json_decode(readfile(g:parameters_file))
endfunction

function! s:set_parameters(parameters) abort
  call writefile([json_encode(a:parameters)], g:parameters_file)
endfunction

function! s:get_build_dir(parameters) abort
  return getcwd() . '-' . a:parameters['buildType'] . '/'
endfunction

function! s:get_reply_dir(build_dir) abort
  return a:build_dir . '.cmake/api/v1/reply/'
endfunction

function! s:get_codemodel_targets(reply_dir) abort
  let codemodel_json = json_decode(readfile(globpath(a:reply_dir, 'codemodel*')))
  return codemodel_json['configurations'][0]['targets']
endfunction

function! s:get_target_info(reply_dir, codemodel_target) abort
    return json_decode(readfile(a:reply_dir . a:codemodel_target['jsonFile']))
endfunction

" Tell CMake to generate codemodel
function! s:make_query_files(build_dir) abort
  let query_dir = a:build_dir . '.cmake/api/v1/query/'
  call mkdir(query_dir, 'p')

  let codemodel_file = query_dir . 'codemodel-v2'
  if !filereadable(codemodel_file)
    call writefile([], codemodel_file)
  endif
endfunction

function! s:get_current_target_with_args() abort
  let parameters = s:get_parameters()
  let build_dir = s:get_build_dir(parameters)
  if !isdirectory(build_dir)
    echo 'You need to configure first'
    return ''
  endif

  let target_name = parameters['currentTarget']
  if empty(target_name)
    echo 'You need to select target first'
    return ''
  endif

  let reply_dir = s:get_reply_dir(build_dir)
  let codemodel_targets = s:get_codemodel_targets(reply_dir)
  let target_info = s:get_target_info(reply_dir, codemodel_targets[target_name])
  if target_info['type'] !=? 'EXECUTABLE'
    echo 'Specified target is not executable: ' . target_name
    return ''
  endif

  let target_path = build_dir . target_info['artifacts'][0]['path']
  if !filereadable(target_path)
    echo 'Selected target is not built: ' . target_path
    return ''
  endif

  return target_path . ' ' . get(parameters['arguments'], target_name)
endfunction

" FZF callbacks
function! s:set_current_target(fzf_string) abort
  let parameters = s:get_parameters()
  let parameters['currentTarget'] = strpart(a:fzf_string, 0, stridx(a:fzf_string, ' '))
  call s:set_parameters(parameters)
endfunction

function! s:set_build_type(build_type) abort
  let parameters = s:get_parameters()
  let parameters['buildType'] = a:build_type
  call s:set_parameters(parameters)
endfunction

" Public interface
function! cmake#configure(additional_arguments) abort
  if !filereadable('CMakeLists.txt')
    echo 'Unable to find CMakeLists.txt'
    return
  endif
  let parameters = s:get_parameters()
  let build_dir = s:get_build_dir(parameters)
  call mkdir(build_dir, 'p')
  call s:make_query_files(build_dir)
  call asyncrun#run('', {}, 'cmake ' . a:additional_arguments . ' -D CMAKE_BUILD_TYPE=' . parameters['buildType'] . ' -D CMAKE_EXPORT_COMPILE_COMMANDS=1 -B ' . build_dir
        \ . ' && ln -sf ' . fnamemodify(build_dir, ':.') . 'compile_commands.json')
endfunction

function! cmake#build(additional_arguments) abort
  if g:cmake_save_before_build
    wall
  endif

  let parameters = s:get_parameters()
  let target = parameters['buildAll'] ? 'all' : parameters['currentTarget']
  call asyncrun#run('', {}, 'cmake ' . a:additional_arguments . ' --build ' . s:get_build_dir(parameters) . ' --target ' . target)
endfunction

function! cmake#run() abort
  let command = s:get_current_target_with_args()
  if !empty(command)
    call asyncrun#run('', {}, command)
  endif
endfunction

function! cmake#debug() abort
  let command = s:get_current_target_with_args()
  if empty(command)
    return
  endif

  if !exists(':Termdebug')
    packadd termdebug
  endif

  execute 'Termdebug ' command
endfunction

function! cmake#clean() abort
  call asyncrun#run('', {}, 'cmake --build ' . s:get_build_dir(s:get_parameters()) . ' --target clean')
endfunction

function! cmake#select_build_type() abort
  let parameters = s:get_parameters()
  let current_build_type = parameters['buildType']
  let fzf_spec = {'source': [], 'sink': function('s:set_build_type'), 'options': ['--header', parameters['buildType']]}
  for build_type in ['Debug', 'Release', 'RelWithDebInfo', 'MinSizeRel']
    if build_type !=? current_build_type
      call add(fzf_spec['source'], build_type)
    endif
  endfor
  call fzf#run(fzf#wrap(fzf_spec))
endfunction

function! cmake#select_target() abort
  let parameters = s:get_parameters()
  let build_dir = s:get_build_dir(parameters)
  if !isdirectory(build_dir)
    echo 'You need to configure first'
    return
  endif

  let fzf_spec = {'source': [], 'sink': function('s:set_current_target'), 'options': []}
  let current_target = parameters['currentTarget']
  if !empty(current_target)
    let fzf_spec['options'] += ['--header', current_target]
  endif

  let reply_dir = s:get_reply_dir(build_dir)
  for target in s:get_codemodel_targets(reply_dir)
    let target_info = s:get_target_info(reply_dir, target)
    let target_name = target_info['name']
    let target_type = target_info['type']
    if target_type !=? 'UTILITY' && target_name !=? current_target
      call add(fzf_spec['source'], target_name . ' (' . tolower(target_type) . ')')
    endif
  endfor

  call fzf#run(fzf#wrap(fzf_spec))
endfunction

function! cmake#set_target_arguments() abort
  let parametets = s:get_parameters()
  let current_target = parametets['currentTarget']
  if empty(current_target)
    echo 'You need to select target first'
    return
  endif
  let parametets['arguments'][current_target] = input(current_target . ' arguments: ', get(parametets['arguments'], current_target , ''))
  call s:set_parameters(parametets)
endfunction

function! cmake#toogle_build_all() abort
  let parameters = s:get_parameters()
  let parameters['buildAll'] = !parameters['buildAll']
  call s:set_parameters(parameters)
  echo 'Build all targets' parameters['buildAll'] ? 'enabled' : 'disabled'
endfunction
