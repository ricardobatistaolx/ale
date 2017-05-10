" Author: w0rp <devw0rp@gmail.com>
" Deciption: APIs for working with Asynchronous jobs, with an API normalised
" between Vim 8 and NeoVim.

let s:job_map = {}
" A map from timer IDs to jobs, for tracking jobs that need to be killed
" with SIGKILL if they don't terminate right away.
let s:job_kill_timers = {}

function! s:KillHandler(timer) abort
    let l:job = remove(s:job_kill_timers, a:timer)
    call job_stop(l:job, 'kill')
endfunction

function! ale#job#JoinNeovimOutput(output, data) abort
    if empty(a:output)
        call extend(a:output, a:data)
    else
        " Extend the previous line, which can be continued.
        let a:output[-1] .= get(a:data, 0, '')

        " Add the new lines.
        call extend(a:output, a:data[1:])
    endif
endfunction

function! s:HandleNeoVimLines(job, callback, output, data) abort
    call ale#job#JoinNeovimOutput(a:output, a:data)

    for l:line in a:output
        call a:callback(a:job, l:line)
    endfor
endfunction

function! s:NeoVimCallback(job, data, event) abort
    let l:job_info = s:job_map[a:job]

    if a:event ==# 'stdout'
        call s:HandleNeoVimLines(
        \   a:job,
        \   ale#util#GetFunction(l:job_info.out_cb),
        \   l:job_info.out_cb_output,
        \   a:data,
        \)
    elseif a:event ==# 'stderr'
        call s:HandleNeoVimLines(
        \   a:job,
        \   ale#util#GetFunction(l:job_info.err_cb),
        \   l:job_info.err_cb_output,
        \   a:data,
        \)
    else
        call ale#util#GetFunction(l:job_info.exit_cb)(a:job, a:data)
    endif
endfunction

function! s:VimOutputCallback(channel, data) abort
    let l:job = ch_getjob(a:channel)
    let l:job_id = ale#job#ParseVim8ProcessID(string(l:job))
    call ale#util#GetFunction(s:job_map[l:job_id].out_cb)(l:job, a:data)
endfunction

function! s:VimErrorCallback(channel, data) abort
    let l:job = ch_getjob(a:channel)
    let l:job_id = ale#job#ParseVim8ProcessID(string(l:job))
    call ale#util#GetFunction(s:job_map[l:job_id].err_cb)(l:job, a:data)
endfunction

function! s:VimExitCallback(job, exit_code) abort
    let l:job_id = ale#job#ParseVim8ProcessID(string(a:job))
    call ale#util#GetFunction(s:job_map[l:job_id].exit_cb)(a:job, a:exit_code)
endfunction

function! ale#job#ParseVim8ProcessID(job_string) abort
    return matchstr(a:job_string, '\d\+') + 0
endfunction

function! ale#job#GetID(job) abort
    if has('nvim')
        return a:job
    endif

    " TODO: Type check the job.
    return ale#job#ParseVim8ProcessID(string(a:job))
endfunction

function! ale#job#ValidateArguments(command, options) abort
    if a:options.mode !=# 'nl' && a:options.mode !=# 'raw'
        throw 'Invalid mode: ' . a:options.mode
    endif
endfunction

function! ale#job#Start(command, options) abort
    call ale#job#ValidateArguments(a:command, a:options)

    let l:job_info = copy(a:options)
    let l:job_options = {}

    if has('nvim')
        if has_key(a:options, 'out_cb')
            let l:job_options.on_stdout = function('s:NeoVimCallback')
            let l:job_options.out_cb_output = []
        endif

        if has_key(a:options, 'err_cb')
            let l:job_options.on_stderr = function('s:NeoVimCallback')
            let l:job_options.err_cb_output = []
        endif

        if has_key(a:options, 'exit_cb')
            let l:job_options.on_exit = function('s:NeoVimCallback')
        endif

        let l:job = jobstart(a:command, l:job_options)
    else
        let l:job_options = {
        \   'in_mode': l:job_info.mode,
        \   'out_mode': l:job_info.mode,
        \   'err_mode': l:job_info.mode,
        \}

        if has_key(a:options, 'out_cb')
            let l:job_options.out_cb = function('s:VimOutputCallback')
        endif

        if has_key(a:options, 'err_cb')
            let l:job_options.err_cb = function('s:VimErrorCallback')
        endif

        if has_key(a:options, 'exit_cb')
            let l:job_options.exit_cb = function('s:VimExitCallback')
        endif

        " Vim 8 will read the stdin from the file's buffer.
        let l:job = job_start(a:command, l:job_options)
    endif

    let l:job_id = ale#job#GetID(l:job)

    if l:job_id
        " Store the job in the map for later only if we can get the ID.
        let s:job_map[l:job_id] = l:job_info
    endif

    return l:job
endfunction

" Given a job, return 1 if the job is currently running.
function! ale#job#IsRunning(job) abort
    if has('nvim')
        try
            " In NeoVim, if the job isn't running, jobpid() will throw.
            call jobpid(a:job)
            return 1
        catch
        endtry

        return 0
    endif

    return job_status(a:job) ==# 'run'
endfunction

function! ale#job#Stop(job) abort
    if has('nvim')
        " FIXME: NeoVim kills jobs on a timer, but will not kill any processes
        " which are child processes on Unix. Some work needs to be done to
        " kill child processes to stop long-running processes like pylint.
        call jobstop(a:job)
    else
        " We must close the channel for reading the buffer if it is open
        " when stopping a job. Otherwise, we will get errors in the status line.
        if ch_status(job_getchannel(a:job)) ==# 'open'
            call ch_close_in(job_getchannel(a:job))
        endif

        " Ask nicely for the job to stop.
        call job_stop(a:job)

        if ale#job#IsRunning(a:job)
            " Set a 100ms delay for killing the job with SIGKILL.
            let s:job_kill_timers[timer_start(100, function('s:KillHandler'))] = a:job
        endif
    endif
endfunction
