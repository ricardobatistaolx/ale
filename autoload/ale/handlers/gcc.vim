scriptencoding utf-8
" Author: w0rp <devw0rp@gmail.com>
" Description: This file defines a handler function which ought to work for
" any program which outputs errors in the format that GCC uses.

function! s:AddIncludedErrors(output, include_lnum, include_lines) abort
    if a:include_lnum > 0
        call add(a:output, {
        \   'lnum': a:include_lnum,
        \   'type': 'E',
        \   'text': 'Problems were found in the header (See :ALEDetail)',
        \   'detail': join(a:include_lines, "\n"),
        \})
    endif
endfunction

function! ale#handlers#gcc#HandleGCCFormat(buffer, lines) abort
    let l:first_include_filename = ''
    let l:include_pattern = '\v^In file included from (.*):(\d+):'
    let l:include_lnum = 0
    let l:include_lines = []
    " Look for lines like the following.
    "
    " <stdin>:8:5: warning: conversion lacks type at end of format [-Wformat=]
    " <stdin>:10:27: error: invalid operands to binary - (have ‘int’ and ‘char *’)
    " -:189:7: note: $/${} is unnecessary on arithmetic variables. [SC2004]
    let l:pattern = '^\(.\+\):\(\d\+\):\(\d\+\): \([^:]\+\): \(.\+\)$'
    let l:output = []

    for l:line in a:lines
        let l:match = matchlist(l:line, l:pattern)

        if l:include_lnum > 0
        \&& !empty(l:match)
        \&& l:match[1] ==# l:first_include_filename
            call s:AddIncludedErrors(l:output, l:include_lnum, l:include_lines)
            let l:include_lnum = 0
            let l:include_lines = []
        endif

        if empty(l:match)
            let l:include_match = matchlist(l:line, l:include_pattern)

            if !empty(l:include_match)
                if empty(l:first_include_filename)
                    let l:first_include_filename = l:include_match[1]
                endif

                let l:include_lnum = str2nr(l:include_match[2])
            endif

            continue
        endif

        call add(l:output, {
        \   'lnum': l:match[2] + 0,
        \   'col': l:match[3] + 0,
        \   'type': l:match[4] =~# 'error' ? 'E' : 'W',
        \   'text': l:match[5],
        \})
    endfor

    call s:AddIncludedErrors(l:output, l:include_lnum, l:include_lines)

    return l:output
endfunction
