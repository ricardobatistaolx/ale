" Author: Ricardo Batista <ricardo.batista@olx.com>
" Description: This file adds support for checking PHP with phpstan

function! ale_linters#php#php#Handle(buffer, lines) abort
    let l:pattern = '^\s\+\(\d\+\)\(.\+\)'
    let l:output = []

    for i in a:lines
        echom i
    endfor

    for l:match in ale#util#GetMatches(a:lines, l:pattern)
        for i in l:match
            echom i
        endfor


        let l:obj = {
        \   'lnum': l:match[1] + 0,
        \   'col': 0,
        \   'text': l:match[2],
        \   'type': 'E',
        \}

        call add(l:output, l:obj)
    endfor

    return l:output
endfunction

call ale#linter#Define('php', {
\   'name': 'phpstan',
\   'executable': 'phpstan',
\   'output_stream': 'stdout',
\   'command': 'phpstan analyse -l 4 %s',
\   'callback': 'ale_linters#php#php#Handle',
\})
