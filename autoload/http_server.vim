function! http_server#new(host, port) abort
  let obj = {
    \ 'alive': 1,
    \ 'host': a:host,
    \ 'port': a:port,
    \ }

  " This function is called when a line is sent from a client to our server.
  function! obj._out_cb(channel, msg) abort
    echom "Got: ".a:msg
  endfunction

  " This function is called when a error occurs.
  " TODO: What to do on errors?
  function! obj._err_cb(channel, msg) abort
    echoerr a:msg
  endfunction

  function! obj.stop() abort
    call job_stop(self.job)
    let self.alive = 0
  endfunction

  let job = job_start('nc -lk '.a:host.' '.a:port, {
    \ 'out_cb': obj._out_cb,
    \ 'err_cb': obj._err_cb,
    \ })
  let obj.job = job
  let obj.channel = job_getchannel(job)

  return obj
endfunction

