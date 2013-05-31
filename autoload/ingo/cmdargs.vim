" ingo/cmdargs.vim: Functions for parsing of command arguments.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.006.006	29-May-2013	Again change
"				ingo#cmdargs#ParseSubstituteArgument() interface
"				to parse the :substitute [flags] [count] by
"				default.
"   1.006.005	28-May-2013	BUG: ingo#cmdargs#ParseSubstituteArgument()
"				mistakenly returns a:defaultFlags when full
"				/pat/repl/ or a literal pat is passed. Only
"				return a:defaultFlags when the passed
"				a:arguments is really empty.
"				CHG: Redesign
"				ingo#cmdargs#ParseSubstituteArgument() interface
"				to the existing use cases. a:defaultReplacement
"				should only be used when a:arguments is really
"				empty, too. Introduce an optional options
"				Dictionary and preset replacement / flags
"				defaults of "~" and "&" resp. for when
"				a:arguments is really empty, which makes sense
"				for use with :substitute. Allow submatches for
"				a:flagsExpr via a:options.flagsMatchCount, to
"				avoid further parsing in the client.
"				ENH: Also parse lone {flags} (if a:flagsExpr is
"				given) by default, and allow to turn this off
"				via a:options.isAllowLoneFlags.
"				ENH: Allow to pass a:options.emptyPattern, too.
"   1.001.004	21-Feb-2013	Move to ingo-library.
"	003	29-Jan-2013	Add ingocmdargs#ParseSubstituteArgument() for
"				use in PatternsOnText/Except.vim and
"				ExtractMatchesToReg.vim.
"				Change ingocmdargs#UnescapePatternArgument() to
"				take the result of
"				ingocmdargs#ParsePatternArgument() instead of
"				invoking that function itself. And make it
"				handle an empty separator.
"	002	21-Jan-2013	Add ingocmdargs#ParsePatternArgument() and
"				ingocmdargs#UnescapePatternArgument() from
"				PatternsOnText.vim.
"	001	25-Nov-2012	file creation from CaptureClipboard.vim.

function! ingo#cmdargs#GetStringExpr( argument )
    try
	if a:argument =~# '^\([''"]\).*\1$'
	    " The argument is quotes, evaluate it.
	    execute 'let l:expr =' a:argument
	elseif a:argument =~# '\\'
	    " The argument contains escape characters, evaluate them.
	    execute 'let l:expr = "' . a:argument . '"'
	else
	    let l:expr = a:argument
	endif
    catch /^Vim\%((\a\+)\)\=:E/
	let l:expr = a:argument
    endtry
    return l:expr
endfunction


function! ingo#cmdargs#ParsePatternArgument( arguments, ... )
    let l:match = matchlist(a:arguments, '^\(\i\@!\S\)\(.\{-}\)\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\1' . (a:0 ? a:1 : '') . '$')
    if empty(l:match)
	return ['/', escape(a:arguments, '/')] + (a:0 ? [''] : [])
    else
	return l:match[1: (a:0 ? 3 : 2)]
    endif
endfunction
function! ingo#cmdargs#UnescapePatternArgument( parsedArguments )
"******************************************************************************
"* PURPOSE:
"   Unescape the use of the separator from the parsed pattern to yield a plain
"   regular expression, e.g. for use in search().
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:parsedArguments   List with at least two elements: [separator, pattern].
"			separator may be empty; in that case; pattern is
"			returned as-is.
"			You're meant to directly pass the output of
"			ingo#cmdargs#ParsePatternArgument() in here.
"* RETURN VALUES:
"   If a:parsedArguments contains exactly two arguments: unescaped pattern.
"   Else a List where the first element is the unescaped pattern, and all
"   following elements are taken from the remainder of a:parsedArguments.
"******************************************************************************
    " We don't need the /.../ separation here.
    let l:separator = a:parsedArguments[0]
    let l:unescapedPattern = (empty(l:separator) ?
    \   a:parsedArguments[1] :
    \   substitute(a:parsedArguments[1], '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\\\V\C' . l:separator, l:separator, 'g')
    \)

    return (len(a:parsedArguments) > 2 ? [l:unescapedPattern] + a:parsedArguments[2:] : l:unescapedPattern)
endfunction

function! s:EnsureList( val )
    return (type(a:val) == type([]) ? a:val : [a:val])
endfunction
function! s:ApplyEmptyFlags( emptyFlags, parsedFlags)
    return (empty(filter(copy(a:parsedFlags), '! empty(v:val)')) ? a:emptyFlags : a:parsedFlags)
endfunction
function! ingo#cmdargs#ParseSubstituteArgument( arguments, ... )
"******************************************************************************
"* PURPOSE:
"   Parse the arguments of a custom command that works like :substitute.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:arguments The command's raw arguments; usually <q-args>.
"   a:options.flagsExpr             Pattern that captures any optional part
"				    after the replacement (usually some
"				    substitution flags). By default, captures
"				    the known :substitute |:s_flags| and
"				    optional [count]. Pass an empty string to
"				    disallow any flags.
"   a:options.additionalFlags       Flags that will be recognized in addition to
"				    the default |:s_flags|; default none. Modify
"				    this instead of passing a:options.flagsExpr
"				    if you want to recognize additional flags.
"   a:options.flagsMatchCount       Optional number of submatches captured by
"				    a:options.flagsExpr. Defaults to 2 with the
"				    default a:options.flagsExpr, to 1 with a
"				    non-standard non-empty
"				    a:options.flagsMatchCount, and 0 if
"				    a:options.flagsMatchCount is empty.
"   a:options.defaultReplacement    Replacement to use when the replacement part
"				    is omitted. Empty by default.
"   a:options.emptyPattern          Pattern to use when no arguments at all are
"				    given. Defaults to "", which automatically
"				    uses the last search pattern in a
"				    :substitute. You need to escape this
"				    yourself (to be able to pass in @/, which
"				    already is escaped).
"   a:options.emptyReplacement      Replacement to use when no arguments at all
"				    are given. Defaults to "~" to use the
"				    previous replacement in a :substitute.
"   a:options.emptyFlags            Flags to use when a:options.flagsExpr is not
"				    empty, but no arguments at all are given.
"				    Defaults to "&" to use the previous flags of
"				    a :substitute. Provide a List if
"				    a:options.flagsMatchCount is larger than 1.
"   a:options.isAllowLoneFlags      Allow to omit /pat/repl/, and parse a
"				    stand-alone a:options.flagsExpr (assuming
"				    one is passed). On by default.
"* RETURN VALUES:
"   A list of [separator, pattern, replacement, flags, count] (default, count
"   and flags may be omitted or more elements added depending on the
"   a:options.flagsExpr and a:options.flagsMatchCount).
"   flags and count are meant to be directly concatenated; count therefore keeps
"   leading whitespace, but be aware that this is optional with :substitute,
"   too!
"   The replacement part is always escaped for use inside separator, also when
"   the default is taken.
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:additionalFlags = get(l:options, 'additionalFlags', '')
    let l:flagsExpr = get(l:options, 'flagsExpr', '\(&\?[cegiInp#lr' . l:additionalFlags . ']*\)\(\s*\d*\)')
    let l:isParseFlags = (! empty(l:flagsExpr))
    let l:flagsMatchCount = get(l:options, 'flagsMatchCount', (has_key(l:options, 'flagsExpr') ? (l:isParseFlags ? 1 : 0) : 2))
    let l:defaultFlags = (l:isParseFlags ? repeat([''], l:flagsMatchCount) : [])
    let l:defaultReplacement = get(l:options, 'defaultReplacement', '')
    let l:emptyPattern = get(l:options, 'emptyPattern', '')
    let l:emptyReplacement = get(l:options, 'emptyReplacement', '~')
    let l:emptyFlags = get(l:options, 'emptyFlags', ['&'] + repeat([''], l:flagsMatchCount - 1))
    let l:isAllowLoneFlags = get(l:options, 'isAllowLoneFlags', 1)

    let l:matches = matchlist(a:arguments, '^\(\i\@!\S\)\(.\{-}\)\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\1\(.\{-}\)\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\1' . l:flagsExpr . '$')
    if ! empty(l:matches)
	" Full /pat/repl/[flags].
	return l:matches[1:3] + (l:isParseFlags ? l:matches[4:(4 + l:flagsMatchCount - 1)] : [])
    endif

    let l:matches = matchlist(a:arguments, '^\(\i\@!\S\)\(.\{-}\)\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\1\(.\{-}\)$')
    if ! empty(l:matches)
	" Partial /pat/[repl].
	return l:matches[1:2] + [(empty(l:matches[3]) ? escape(l:defaultReplacement, l:matches[1]) : l:matches[3])] + l:defaultFlags
    endif

    let l:matches = matchlist(a:arguments, '^\(\i\@!\S\)\(.\{-}\)$')
    if ! empty(l:matches)
	" Minimal /[pat].
	return l:matches[1:2] + [escape(l:defaultReplacement, l:matches[1])] + l:defaultFlags
    endif

    if l:isParseFlags && l:isAllowLoneFlags
	let l:matches = matchlist(a:arguments, '^' . l:flagsExpr . '$')
	if ! empty(l:matches)
	    " Special case of {flags} without /pat/string/.
	    return ['/', l:emptyPattern, escape(l:emptyReplacement, '/')] + s:ApplyEmptyFlags(s:EnsureList(l:emptyFlags), l:matches[1:(l:flagsMatchCount)])
	endif
    endif

    if ! empty(a:arguments)
	" Literal pat.
	if ! empty(l:defaultReplacement)
	    " Clients cannot concatentate the results without a separator, so
	    " use one.
	    return ['/', escape(a:arguments, '/'), escape(l:defaultReplacement, '/')] + l:defaultFlags
	else
	    return ['', a:arguments, l:defaultReplacement] + l:defaultFlags
	endif
    else
	" Nothing.
	return ['/', l:emptyPattern, escape(l:emptyReplacement, '/')] + (l:isParseFlags ? s:EnsureList(l:emptyFlags) : [])
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
