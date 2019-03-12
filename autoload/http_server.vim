function! http_server#new(host, port) abort
  let job = job_start('nc -lk '.a:host.' '.a:port)
  let obj = {
    \ 'alive': 1,
    \ 'host': a:host,
    \ 'port': a:port,
    \ 'job': job,
    \ 'channel': job_getchannel(job),
    \ }

  function! obj.stop() abort
    call job_stop(self.job)
    let self.alive = 0
  endfunction

  return obj
endfunction

function! http_server#accept(srv) abort
  " Read a line from netcat. This *should* be the beginning of a request.
  let line = ch_read(a:srv.channel)
  echom 'Line: '.line
endfunction
