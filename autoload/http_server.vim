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
    \ '_current_request': {},
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
        " In reality, this is the end of the message... Just trust the
        " process.
        return self._close_cb()
      else
        let header_match = matchlist(a:msg, '\([^:]\+\):\s*\([^\r\n]\+\)')
        if (empty(header_match))
          " This is not a header, consider it to be body content.
          let self.state = 'body'
        let self._current_request.body .= a:msg
          "return self._err_cb(self.channel, 'Expected request header, found "'.a:msg.'" instead.')
        else
          let key = tolower(header_match[1])
          let value = header_match[2]
          let self._current_request.headers[key] = value
        endif
      endif
    elseif (self.state == 'body')
      if (empty(a:msg))
        return self._close_cb()
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

  function! obj._close_cb(...) abort
    " Finalize the request
    let old_job = self.job
    let channel = self.channel
    let request = self._current_request

    " Reset the server, and restart it.
    let self._current_request = {}
    let self.state = 'idle'
    let job = job_start('nc -l '.self.host.' '.self.port, {
      \ 'out_cb': self._out_cb,
      \ 'err_cb': self._err_cb,
      \ 'close_cb': self._close_cb
      \ })
    let self.job = job
    let self.channel = job_getchannel(job)

    " Create a response object
    let response = {'channel': channel, 'job': old_job}

    function! response.write(msg) abort

    endfunction

    " Invoke the callback
    return self.Callback(request, response)
  endfunction

  function! obj.stop() abort
    call job_stop(self.job)
    let self.alive = 0
  endfunction

  let job = job_start('nc -l '.a:host.' '.a:port, {
    \ 'out_cb': obj._out_cb,
    \ 'err_cb': obj._err_cb,
    \ 'close_cb': obj._close_cb
    \ })
  let obj.job = job
  let obj.channel = job_getchannel(job)

  return obj
endfunction

