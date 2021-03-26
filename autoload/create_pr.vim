let s:git_services = extend({
      \ 'github.com': 'https://github.com/{{owner}}/{{repository}}/compare/{{branch_name}}?expand=1',
      \ 'bitbucket.org': 'https://bitbucket.org/{{owner}}/{{repository}}/pull-requests/new?source={{branch_name}}&t=1',
      \ 'gitlab.com': 'https://gitlab.com/{{owner}}/{{repository}}/merge_requests/new?merge_request[source_branch]={{branch_name}}',
\ }, get(g:, 'create_pr_git_services', {}))

function! create_pr#from_cmdline(...) abort
  let l:branch_name = !empty(get(a:, '1'))
        \ ? a:1
        \ : s:get_current_branch_name()

  return s:open_pr(l:branch_name)
endfunction

function! create_pr#from_twiggy() abort
  let l:branch = TwiggyBranchUnderCursor()

  return s:open_pr(l:branch.fullname)
endfunction

function! create_pr#open_repo_page()
  let l:remote_url = s:get_remote_url()
  let l:browser_executable = s:get_browser()

  return s:system_async(escape(printf('%s %s', l:browser_executable, l:remote_url), '?&%'))
endfunction

function! s:open_pr(branch) abort
  try
    call s:check_remote_exists(a:branch)

    let l:remote_url = s:get_remote_url()
    let l:git_service = s:get_git_service(l:remote_url)

    let l:url = s:generate_url(l:git_service, l:remote_url, a:branch)
    let l:browser_executable = s:get_browser()

    return s:system_async(escape(printf('%s %s', l:browser_executable, l:url), '?&%'))
  catch /.*/
    return s:error(v:exception)
  endtry
endfunction

function s:generate_url(git_service, remote_url, branch) abort
  let [l:owner, l:repository] = s:get_repo_info_from_remote_url(a:remote_url)

  let l:url = substitute(copy(a:git_service), '{{owner}}', l:owner, '')
  let l:url = substitute(l:url, '{{repository}}', l:repository, '')
  let l:url = substitute(l:url, '{{branch_name}}', a:branch, '')

  return l:url
endfunction

function! s:get_git_service(remote_url) abort
  let l:service = ''
  for l:git_service in keys(s:git_services)
    if a:remote_url =~? l:git_service
      let l:service = s:git_services[l:git_service]
      break
    endif
  endfor

  if empty(l:service)
    throw printf('Unsupported git service for remote url %s', a:remote_url)
  endif

  return l:service
endfunction

function! s:get_repo_info_from_remote_url(remote_url) abort
  let l:is_http = a:remote_url =~? '^https\?:\/\/'
  let l:is_ssh = a:remote_url =~? '^ssh:\/\/'
  if l:is_http || l:is_ssh
    let l:splits = split(a:remote_url, '/')
    let l:repository = substitute(l:splits[-1], '\.git$', '', '')
    let l:owner = l:splits[-2]
    return [l:owner, l:repository]
  endif

  let l:splits = split(a:remote_url, ':')[-1]
  let [l:owner, l:repository] = split(l:splits, '/')
  return [l:owner, substitute(l:repository, '\.git$', '', '')]
endfunction

function! s:get_browser() abort
  if !empty(g:create_pr_browser)
    return g:create_pr_browser
  endif

  if executable('xdg-open')
    return 'xdg-open'
  endif

  if has('win32')
    return 'start'
  endif

  if executable('open')
    return 'open'
  endif

  if executable('google-chrome')
    return 'google-chrome'
  endif

  if executable('firefox')
    return 'firefox'
  endif

  throw 'Browser not found'
endfunction

function! s:get_remote_url() abort
  let l:remote_url = s:system('git config --get remote.origin.url')

  if empty(l:remote_url)
    throw 'Not a valid git repository'
  endif

  return l:remote_url
endfunction

function! s:check_remote_exists(branch) abort
  let l:remote = s:system(printf('git show-ref --verify -- refs/remotes/origin/%s', a:branch))

  if l:remote =~? 'not a valid ref'
    throw printf('Remote does not exist for branch "%s"', a:branch)
  endif

  return v:true
endfunction

function! s:get_current_branch_name() abort
  let l:branch_name = s:system('git rev-parse --abbrev-ref HEAD')

  if empty(l:branch_name)
    throw 'Could not parse branch name. Please provide it manually.'
  endif

  return l:branch_name
endfunction

function! s:system(cmd) abort
  let l:output = systemlist(a:cmd)
  return get(l:output, 0, '')
endfunction

function! s:system_async(cmd) abort
  if has('nvim') && exists('*jobstart')
    return jobstart(a:cmd, { 'detach': v:true })
  endif

  if exists('*job_start')
    return job_start(a:cmd, { 'stoponexit': '' })
  endif

  return s:system(a:cmd)
endfunction

function! s:error(msg) abort
  redraw!
  echohl ErrorMsg
  echo a:msg
  echohl None
endfunction
