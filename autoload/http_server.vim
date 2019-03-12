function! http_server#new(host, port, callback) abort
  if type(a:callback) == v:t_string
    let Callback = function(a:callback)
  elseif type(a:callback) != v:t_func
    echoerr "HTTP server callback is not a string or function: ".a:callback
    return {}
  else
    let Callback = a:callback
  endif
  let obj = {
    \ 'alive': 1,
    \ 'host': a:host,
    \ 'port': a:port,
    \ 'state': 'idle',
    \ 'Callback': Callback,
    \ }

  " This function is called when a line is sent from a client to our server.
  function! obj._out_cb(channel, msg) abort
    if (self.state == 'idle')
      let start_match = matchlist(a:msg, '\([A-Za-z]\+\) \([^\r\n]\+\) HTTP\/1.1')
      if empty(start_match)
        return self._err_cb(self.channel, 'Expected HTTP/1.1 start line, found "'.a:msg.'" instead.')
      else
        " We've parsed the method and path.
        let method = start_match[1]
        let path = start_match[2]
        let self._current_request = {'method': method, 'path': path, 'body': '', 'headers': {}}
        let self.state = 'headers'
      endif
    elseif (self.state == 'headers')
      " Parse a request header.
      if (empty(a:msg))
        let self.state = 'body'
      else
        let header_match = matchlist(a:msg, '\([^:]\+\):\s*\([^\r\n]\+\)')
        if (empty(header_match))
          return self._err_cb(self.channel, 'Expected request header, found "'.a:msg.'" instead.')
        else
          let key = tolower(header_match[1])
          let value = header_match[2]
          let self._current_request.headers[key] = value
        endif
      endif
    elseif (self.state == 'body')
      if (empty(a:msg))
        " Finalize the request
        let channel = self.channel
        let request = self._current_request
        unlet self._current_request
        let self.state = 'idle'

        " Create a response object
        let response = {'channel': channel}

        function! response.write(msg) abort

        endfunction

        " Invoke the callback
        return self.Callback(request, response)
      else
        let self._current_request.body .= a:msg
      endif
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

