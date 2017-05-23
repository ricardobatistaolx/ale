" Author: Ricardo Batista <ricardo.batista@olx.com>
" Description: This file adds support for checking PHP with phpstan

function! ale_linters#php#php#Handle(buffer, lines) abort
    " Matches patterns like the following:
    "
    " Parse error:  syntax error, unexpected ';', expecting ']' in - on line 15
    let l:pattern = '(\d+)(.+)'
    let l:output = []

    for l:match in ale#util#GetMatches(a:lines, l:pattern)
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
\   'name': 'php',
\   'executable': 'phpstan',
\   'output_stream': 'stdout',
\   'command': 'phpstan analyse -l4',
\   'callback': 'ale_linters#php#php#Handle',
\})
