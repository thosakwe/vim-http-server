function Demo_handler(rq, rs) abort
  echom "Got ".a:rq.method." request at path ".a:rq.path
endfunction

let g:srv = http_server#new('localhost', 3000, 'Demo_handler')
