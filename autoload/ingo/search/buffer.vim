" ingo/search/buffer.vim: Functions for searching the buffer.
"
" DEPENDENCIES:
"
" Copyright: (C) 2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.005.001	10-Apr-2013	file creation

function! ingo#search#buffer#IsKeywordMatch( text, startVirtCol )
    return search(
    \   printf('\C\V\%%%dv\<%s\>', a:startVirtCol, escape(a:text, '\')),
    \	'cnW', line('.')
    \)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
