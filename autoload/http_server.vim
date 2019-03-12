function! http_server#new(host, port) abort
  let obj = {
    \ 'alive': 1,
    \ 'host': a:host,
    \ 'port': a:port,
    \ 'state': 'idle',
    \ }

  " This function is called when a line is sent from a client to our server.
  function! obj._out_cb(channel, msg) abort
    if (self.state == 'idle')
      let start_match = matchstr(a:msg, '\([A-Za-z]\+\) \([^\r\n]\+\) HTTP\/1.1')
      if empty(start_match)
        return self._err_cb(self.channel, 'Expected HTTP/1.1 request opening, found "'.a:msg."' instead.")
      else
        " We've parsed the method and path.
        let self._current_request = {'method': method, 'path': path, 'headers': {}}
        let self.state = 'headers'
      endif
    elseif (self.state == 'headers')
      " Parse a request header.
    endif
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

