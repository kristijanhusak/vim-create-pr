if (exists('g:loaded_create_pr'))
  finish
endif
let g:loaded_create_pr = 1

let g:create_pr_browser = get(g:, 'create_pr_browser', '')

function! s:complete_branches(arg_lead, cmd_line, cursor_pos) abort
  let l:branches = systemlist("git branch --format='%(refname:short)\t\t%(upstream:short)'")
  let l:list = []
  for l:branch in l:branches
    let l:info = split(l:branch,"\t\t")
    if len(l:info) >= 2 && !empty(l:info[1])
      call add(l:list, l:info[0])
    endif
  endfor
  return join(l:list, "\n")
endfunction

command! -nargs=? -complete=custom,s:complete_branches PR call create_pr#from_cmdline(<q-args>)
command! -nargs=0 RepoPage call create_pr#open_repo_page()

augroup vim_create_pr
  autocmd!
  autocmd FileType twiggy nnoremap <silent><buffer> pr :call create_pr#from_twiggy()<CR>
augroup END
