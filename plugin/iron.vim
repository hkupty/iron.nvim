function! s:save_pos()
  let s:view = winsaveview()

  call nvim_buf_set_extmark(0, nvim_create_namespace('iron'), s:view.lnum, s:view.col, {'id': 20})
endfunction

function! s:ironSendMotion(mode)
  call luaeval('require("iron").core.send_motion(_A)', a:mode)
endfunction

function! s:send_wrapper(bang, ...)
  let s:args = copy(a:000)

  if a:bang
    let s:ft = &ft
  else
    let s:ft = remove(s:args, 0)
  end

  let s:tbl = join(s:args, " ")

  exec 'lua require("iron").core.send("'.s:ft.'", "'.s:tbl.'")'
endfunction

command! -nargs=? -complete=filetype IronRepl
      \ exec 'lua require("iron").core.repl_for("'
      \ .(empty(<q-args>) ? &ft : <q-args>)
      \ .'")'
command! -nargs=+ -bang IronSend call <SID>send_wrapper(<bang>0, <f-args>)
command! -nargs=? -complete=filetype IronFocus
      \  exec 'lua require("iron").core.focus_on("'
      \ .(empty(<q-args>) ? &ft : <q-args>)
      \ .'")'

" add additional commands to open a REPL in the current buffer and to restart
" a REPL
command! -nargs=? -complete=filetype IronReplHere
    \ exec 'lua require("iron").core.repl_here("'
    \ .(empty(<q-args>) ? &ft : <q-args>)
    \ .'")'
command! IronRestart exec 'lua require("iron").core.repl_restart()'


map <silent> <Plug>(iron-repeat-cmd)   :lua require("iron").core.repeat_cmd()<CR>
map <silent> <Plug>(iron-cr)            <Cmd>IronSend! \13<CR>
map <silent> <Plug>(iron-interrupt)     <Cmd>IronSend! \03<CR>
map <silent> <Plug>(iron-exit)          <Cmd>IronSend! \04<CR>
map <silent> <Plug>(iron-clear)         <Cmd>IronSend! \12<CR>
map <silent> <Plug>(iron-send-motion)   <Cmd>call <SID>save_pos()<bar>set opfunc=<SID>ironSendMotion<CR>g@
map <silent> <Plug>(iron-send-lines)    <Cmd>set opfunc=<SID>ironSendMotion<bar>exe 'norm! 'v:count1.'g@_'<CR>
map <silent> <Plug>(iron-send-line)     :lua require("iron").core.send_line()<CR>
map <silent> <Plug>(iron-visual-send)   :lua require("iron").core.visual_send()<CR>

if !exists('g:iron_map_defaults')
  let g:iron_map_defaults = 1
endif

if !exists('g:iron_map_extended')
  let g:iron_map_extended = 1
endif

if g:iron_map_defaults
    nmap ctr <Plug>(iron-send-motion)
    vmap ctr <Plug>(iron-visual-send)
    nmap cp <Plug>(iron-repeat-cmd)
    nmap <localleader>sl <Plug>(iron-send-line)
endif

if g:iron_map_extended
  nmap c<CR> <Plug>(iron-cr)
  nmap cst <Plug>(iron-interrupt)
  nmap cq <Plug>(iron-exit)
  nmap cl <Plug>(iron-clear)
endif

function! IronWatchFile(fname, command) abort
  augroup IronWatch
    exec "autocmd BufWritePost" a:fname "lua require(\"iron\").core.send(\"" . &ft . "\",\"".  a:command ."\")"
  augroup END
endfunction

function! IronUnwatchFile(fname) abort
  exec "autocmd! IronWatch BufWritePost" a:fname
endfunction

command! -nargs=* IronWatchCurrentFile call IronWatchFile(expand('%'), <q-args>)
command! -nargs=* IronUnwatchCurrentFile call IronUnwatchFile(expand('%'))
