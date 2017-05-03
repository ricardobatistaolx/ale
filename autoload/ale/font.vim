scriptencoding utf8
" Author: w0rp <devw0rp@gmail.com>
" Description: Font detection for prettier characters.

function ale#font#ResetSupportCache() abort
    unlet! s:support
endfunction

function! s:DetectSupport() abort
    if has_key(s:, 'support')
        return s:support
    endif

    if &guifont =~? 'powerline'
        let s:support = 'circles'
    else
        let s:support = 'basic'
    endif

    return s:support
endfunction

function ale#font#GetSuportedDefaultSigns() abort
    if s:DetectSupport() ==# 'circles'
        return ['⚫', '⚫']
    endif

    " Default to ASCII signs.
    return ['>>', '--']
endfunction

function s:GetSignColumnBackground() abort
    redir => l:output
        silent highlight SignColumn
    redir end

    let l:match = matchlist(l:output, '\vguibg\=([^ ]+)')

    return !empty(l:match) ? l:match[1] : 'NONE'
endfunction

function ale#font#GetSuportedDefaultErrorHighlight() abort
    if s:DetectSupport() ==# 'circles'
        return 'highlight ALEErrorSign guifg=Red guibg=' . s:GetSignColumnBackground()
    endif

    return 'highlight link ALEErrorSign error'
endfunction

function ale#font#GetSuportedDefaultWarningHighlight() abort
    if s:DetectSupport() ==# 'circles'
        return 'highlight ALEWarningSign guifg=yellow guibg=' . s:GetSignColumnBackground()
    endif

    return 'highlight link ALEWarningSign todo'
endfunction
