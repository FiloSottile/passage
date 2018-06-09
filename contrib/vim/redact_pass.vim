"
" redact_pass.vim: Switch off the 'viminfo', 'backup', 'writebackup',
" 'swapfile', and 'undofile' globally when editing a password in pass(1).
"
" This is to prevent anyone being able to extract passwords from your Vim
" cache files in the event of a compromise.
"
" Author: Tom Ryder <tom@sanctum.geek.nz>
" License: Same as Vim itself
"
if exists('g:loaded_redact_pass') || &compatible
  finish
endif
if !has('autocmd')
  finish
endif
let g:loaded_redact_pass = 1

" Pattern to match for the portion of the path after the temporary dir,
" starting with the leading slash
let s:pattern = '\m\C/pass\.[^/]\+/[^/]\+\.txt$'

" Check whether the given dir name is not an empty string, whether the first
" file in the argument list is within the named dir, and that the whole path
" matches the above pattern immediately after that dir name
function! s:PassPath(root)

  " Check we actually got a value, i.e. this wasn't an empty environment
  " variable
  if !strlen(a:root)
    return 0
  endif

  " Full resolved path to the root dir with no trailing slashes
  let l:root = fnamemodify(a:root, ':p:h')

  " Full resolved path to the first file in the arg list
  let l:path = fnamemodify(argv(0), ':p')

  " Check the string all match and at the expected points
  return stridx(l:path, l:root) == 0
        \ && strlen(l:root) == match(l:path, s:pattern)

endfunction

" Check whether we should set redacting options or not
function! s:CheckArgsRedact()

  " Short-circuit unless we're editing just one file and it looks like a path
  " in one of the three expected directories; we're trying hard to make sure
  " this really is a password file and we're not messing with the user's
  " precious settings unnecessarily
  if argc() != 1
        \ || !s:PassPath('/dev/shm')
        \ && !s:PassPath($TMPDIR)
        \ && !s:PassPath('/tmp')
    return
  endif

  " Disable all the leaky options globally
  set nobackup
  set nowritebackup
  set noswapfile
  set viminfo=
  if has('persistent_undo')
    set noundofile
  endif

  " Tell the user what we're doing so they know this worked, via a message and
  " a global variable they can check
  echomsg 'Editing password file--disabled leaky options!'
  let g:redact_pass_redacted = 1

endfunction

" Auto function loads only when Vim starts up
augroup redact_pass
  autocmd!
  autocmd VimEnter * call s:CheckArgsRedact()
augroup END
