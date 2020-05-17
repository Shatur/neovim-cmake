" Helpers
function! s:get_parameters() abort
  if !filereadable(g:cmake_parameters_file)
    return {'currentTarget': '', 'buildType': 'Debug', 'buildAll': v:true, 'arguments': {}}
  endif
  return json_decode(readfile(g:cmake_parameters_file))
endfunction

function! s:set_parameters(parameters) abort
  call writefile([json_encode(a:parameters)], g:cmake_parameters_file)
endfunction

function! s:get_build_dir(parameters) abort
  return getcwd() . '-' . a:parameters['buildType'] . '-build/'
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

function! s:get_current_executable_info(parameters, build_dir) abort
  if !isdirectory(a:build_dir)
    echom 'You need to configure first'
    return ''
  endif

  let target_name = a:parameters['currentTarget']
  if empty(target_name)
    echom 'You need to select target first'
    return ''
  endif

  let reply_dir = s:get_reply_dir(a:build_dir)
  let codemodel_targets = s:get_codemodel_targets(reply_dir)
  let target_info = s:get_target_info(reply_dir, codemodel_targets[target_name])
  if target_info['type'] !=? 'EXECUTABLE'
    echom 'Specified target is not executable: ' . target_name
    return ''
  endif

  return target_info
endfunction

function! s:get_current_command() abort
  let parameters = s:get_parameters()
  let build_dir = s:get_build_dir(parameters)
  let target_info = s:get_current_executable_info(parameters, build_dir)
  if empty(target_info)
    return ''
  endif

  let target_path = build_dir . target_info['artifacts'][0]['path']
  if !filereadable(target_path)
    echom 'Selected target is not built: ' . target_path
    return ''
  endif

  return target_path . ' ' . get(parameters['arguments'], target_info['name'])
endfunction

" FZF callbacks
function! s:set_current_target(parameters, fzf_string) abort
  let a:parameters['currentTarget'] = strpart(a:fzf_string, 0, stridx(a:fzf_string, ' '))
  call s:set_parameters(a:parameters)
endfunction

function! s:set_build_type(parameters, build_type) abort
  let a:parameters['buildType'] = a:build_type
  call s:set_parameters(a:parameters)
endfunction

function! s:create_project(project_path, project_type) abort
  let output = system('cp -r "' . g:cmake_samples_path . a:project_type . '" "' . a:project_path . '"')
  if !empty(output)
    echom output
    return
  endif

  execute 'edit ' . a:project_path . '/CMakeLists.txt'
  cd %:h
endfunction

" Public interface
function! cmake#get_build_dir()
  return s:get_build_dir(s:get_parameters())
endfunction

function! cmake#configure(additional_arguments) abort
  if !filereadable('CMakeLists.txt')
    echom 'Unable to find CMakeLists.txt'
    return
  endif

  if g:cmake_autosave
    wall
  endif

  let parameters = s:get_parameters()
  let build_dir = s:get_build_dir(parameters)
  call mkdir(build_dir, 'p')
  call s:make_query_files(build_dir)
  call asyncrun#run('', {}, 'cmake ' . a:additional_arguments . ' -D CMAKE_BUILD_TYPE=' . parameters['buildType'] . ' -D CMAKE_EXPORT_COMPILE_COMMANDS=1 -B ' . build_dir
        \ . ' && ln -sf ' . fnamemodify(build_dir, ':.') . 'compile_commands.json')
endfunction

function! cmake#build(additional_arguments) abort
  if g:cmake_autosave
    wall
  endif

  let parameters = s:get_parameters()
  let target = parameters['buildAll'] ? 'all' : parameters['currentTarget']
  call asyncrun#run('', {}, 'cmake ' . a:additional_arguments . ' --build ' . s:get_build_dir(parameters) . ' --target ' . target)
endfunction

function! cmake#run() abort
  let command = s:get_current_command()
  if !empty(command)
    call asyncrun#run('', {}, command)
  endif
endfunction

function! cmake#debug() abort
  let command = s:get_current_command()
  if empty(command)
    return
  endif

  if !exists(':Termdebug')
    packadd termdebug
  endif

  execute 'Termdebug ' command
endfunction

function! cmake#clean() abort
  call asyncrun#run('', {}, 'cmake --build ' . cmake#get_build_dir() . ' --target clean')
endfunction

function! cmake#build_and_run(additional_arguments) abort
  let parameters = s:get_parameters()
  if empty(s:get_current_executable_info(parameters, s:get_build_dir(parameters)))
    return
  endif

  autocmd User AsyncRunStop ++once if g:asyncrun_status ==? 'success' | call cmake#run() | endif
  call cmake#build(a:additional_arguments)
endfunction

function! cmake#build_and_debug(additional_arguments) abort
  let parameters = s:get_parameters()
  if empty(s:get_current_executable_info(parameters, s:get_build_dir(parameters)))
    return
  endif

  autocmd User AsyncRunStop ++once if g:asyncrun_status ==? 'success' | call cmake#debug() | endif
  call cmake#build(a:additional_arguments)
endfunction

function! cmake#select_build_type() abort
  let parameters = s:get_parameters()
  let current_build_type = parameters['buildType']
  let fzf_spec = {'source': [], 'sink': function('s:set_build_type', [parameters]), 'options': ['--header', parameters['buildType']]}
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
    echom 'You need to configure first'
    return
  endif

  let fzf_spec = {'source': [], 'sink': function('s:set_current_target', [parameters]), 'options': []}
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

function! cmake#create_project() abort
  let project_name = input('Project name: ')
  if empty(project_name)
    redraw
    echom 'Project name cannot be empty'
    return
  endif

  let project_location = input('Create in: ', g:default_cmake_projects_path, 'file')
  if empty(project_location)
    redraw
    echom 'Project path cannot be empty'
    return
  endif
  call mkdir(project_location, 'p')

  " Concatenate received data
  if strcharpart(project_location, strlen(project_location) - 1) ==? '/'
    let project_path = expand(project_location) . project_name
  else
    let project_path = expand(project_location) . '/' . project_name
  endif

  if !empty(glob(project_path))
    redraw
    echom 'Path ' . project_path . ' is already exists'
    return
  endif

  let samples = map(glob(g:cmake_samples_path . '*', v:true, v:true), 'fnamemodify(v:val, ":t")')
  call fzf#run(fzf#wrap({'source': samples, 'sink': function('s:create_project', [project_path]), 'options': []}))
endfunction`

function! cmake#set_target_arguments() abort
  let parameters = s:get_parameters()
  let current_target = s:get_current_executable_info(parameters, s:get_build_dir(parameters))
  if empty(current_target)
    return
  endif

  let current_target_name = current_target['name']
  let parameters['arguments'][current_target_name] = input(current_target_name . ' arguments: ', get(parameters['arguments'], current_target_name))
  call s:set_parameters(parameters)
endfunction

function! cmake#toogle_build_all() abort
  let parameters = s:get_parameters()
  let parameters['buildAll'] = !parameters['buildAll']
  call s:set_parameters(parameters)
  echom 'Build all targets' parameters['buildAll'] ? 'enabled' : 'disabled'
endfunction

function! cmake#open_build_dir() abort
  if has('win32')
    let program = 'start '
  else
    let program = 'xdg-open '
  endif
  call asyncrun#run('', {'silent': v:true}, program . cmake#get_build_dir())
endfunction
