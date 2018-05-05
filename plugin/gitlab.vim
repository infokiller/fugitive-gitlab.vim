" gitlab.vim - gitlab support for fugitive.vim
" Maintainer:   Steven Humphrey <https://github.com/shumphrey>
" Version:      1.1.1

" Plugs in to fugitive.vim and provides a gitlab hook for :Gbrowse
" Relies on fugitive.vim by tpope <http://tpo.pe>
" See fugitive.vim for more details
" Requires fugitive.vim 2.1 or greater
"
" If using https://gitlab.com, everything might just work.
" If using a private gitlab, you need to specify the gitlab domains for your
" gitlab instance.
" e.g.
"   let g:fugitive_gitlab_domains = ['https://gitlab.mydomain.com']
"
" known to work with gitlab 7.14.1 on 2015-09-14

if exists('g:loaded_fugitive_gitlab')
    finish
endif
let g:loaded_fugitive_gitlab = 1


if !exists('g:fugitive_browse_handlers')
    let g:fugitive_browse_handlers = []
endif

if index(g:fugitive_browse_handlers, function('gitlab#fugitive_handler')) < 0
    call insert(g:fugitive_browse_handlers, function('gitlab#fugitive_handler'))
endif

function! s:config() abort
    " omnicomplete currently only works if the gitlab remote is origin
    " rhubarb.vim (github) may load first if one of the remotes is a github
    " remote
    "
    " To support non origin remotes, the implementation must support
    " - Works across repositories that might have different upstream names
    " - Does not conflict with rhubarb or other commit omnicompleters
    let default_remote = 'origin'
    return fugitive#buffer().repo().config('remote.'.default_remote.'.url')
endfunction

augroup gitlab
  autocmd!
  autocmd User Fugitive
        \ if expand('%:p') =~# '\.git[\/].*MSG$' &&
        \   exists('+omnifunc') &&
        \   &omnifunc =~# '^\%(syntaxcomplete#Complete\)\=$' &&
        \   !empty(gitlab#homepage_for_remote(s:config())) |
        \   setlocal omnifunc=gitlab#omnifunc |
        \ endif
  autocmd BufEnter *
        \ if expand('%') ==# '' && &previewwindow && pumvisible() && getbufvar('#', '&omnifunc') ==# 'gitlab#omnifunc' |
        \    setlocal nolist linebreak filetype=markdown |
        \ endif
augroup END

let g:gitlab_snippets = {}

" autocompletion for :Gsnip command
" completes the previous snippet id and the remote name
function! s:write_snippet_comp(lead, cmd, pos) abort
    let list = [ '-d', '-p', '-t', '-u', '-v' ]

    let remotes = keys(g:gitlab_api_keys)
    try
        let repo = fugitive#buffer().repo()
        call extend(remotes, split(repo.git_chomp('remote', 'show'), "\n"))
    catch
    endtry

    call extend(list, map(remotes, '"@" . v:val'))

    let visibilities = ['public', 'internal', 'private']

    if match(a:cmd, '-v\s\+\w*$') > -1
        return filter(visibilities, 'v:val =~# "^' . a:lead .'"')
    endif

    return filter(list, 'v:val =~# "^' . a:lead . '"')
endfunction

function! s:list_snippet_comp(lead, cmd, pos) abort
    let list = []

    let remotes = keys(g:gitlab_api_keys)
    try
        let repo = fugitive#buffer().repo()
        call extend(remotes, split(repo.git_chomp('remote', 'show'), "\n"))
    catch
    endtry

    call extend(list, map(remotes, '"@" . v:val'))

    return filter(list, 'v:val =~# "^' . a:lead . '"')
endfunction

command! -nargs=* -complete=customlist,s:list_snippet_comp GsnipList call gitlab#snippet#list(<f-args>)
command! -bar -bang -range=% -nargs=* -complete=customlist,s:write_snippet_comp Gsnip call gitlab#snippet#write(<bang>0, <line1>, <line2>, <f-args>)

" vim: set ts=4 sw=4 et
