#!/bin/zsh

# Preamble

setopt pipefail
setopt rc_quotes
setopt re_match_pcre

zmodload zsh/mathfunc
zmodload zsh/pcre
zmodload zsh/mapfile
autoload -U regexp-replace

## Unicode symbols in synth
local __pipe__='⇝'
local __llit__='«'
local __rlit__='»'
local __lque__='⟦'
local __rque__='⟧'
local __lsep__='↦'
local __rep__='➭:'
local __tok__='ψ'
local __block_size__='1000'

## To avoid overuse of quotes
export nl=$'\n'
export cr=$'\r'
export wh=$' '
export tb=$'\t'
export null=$'\0'
export i_s=$'\n'
export o_s=$'\n'
export f_s=$tb

## For conciseness in user-created functions
alias lex='local x; x=("${(@)__buf__}")'
alias rex='__buf__=("${(@)x}")'

alias ⛥='<<(printf $i_s) ➢ '
alias ◎='out'
alias ◍='out --no-empty'
alias ➢='synth'
alias ⇶='synth --byblocks'
alias reduce='foldl'
alias tabulate='segment'
alias λ='lambda'

alias swap='map Swap'
alias keep='map Keep'
alias excise='map Excise'
alias permute='map Permute'
alias freplace='map Freplace'
alias separate='map Separate'
alias regex_freplace='map Regex_freplace'
alias over='map Over'
alias actf='map actF'
alias unbox='map Unbox'
alias turn='regex_replace'
alias turnf='map Regex_freplace'
# Synthesis main functions

## Building blocks for user-defined functions

input() {
	eval "$1"'=("${(@)__buf__}")'
}

spl() {
	eval "$1"'=("${(@ps:$f_s:)'"$1"'}")'
}

ret() {
	__buf__=("${(@P)@[1]-$1}")
}

## Internal debugging and messages

__debug() {	
	printf "Debug:\t" >&2 
	print -rn -- "$*" >&2
	echo >&2
	[[ $__exec_string__  && $* =~ '(E|e)val' ]] && {
		print -n "\tEval string:" >&2
		print -r -- "'$__exec_string__'" >&2
	}
	[[ $__literal__ ]] && {
		print -n "\tLiteral contents:" >&2
		print -r -- "'$__literal__'" >&2
	}
	[[ $__question__ ]] && {
		print -n "\tQuestion contents:" >&2
		print -r -- "'$__question__'" >&2
	}
}

mock() {
	local fun=$1
	lex
	x="($x)-$fun->"
	rex
}

passthrough() {
	local foo
	input foo
	ret foo
}

witch () {
	local __llit__='«' __rlit__='»' 
	local __rep__='➭:' __pipe__='⇝'
	synth map regex_replace '«$__pipe__➭:$nl$tb$__pipe__»' ⇝ out < <(which $@)
}

## Buffer Input / Output

publish() {
	eval 'typeset -g '"${@[1]:-__buf__}"'="${(pj:$i_s:)__buf__}"'
}

out() {
	[[ $__buf__ || ! $1 =~ '--no-empty' ]] &&
		print -rn -- "${(pj:$o_s:)__buf__[@]}""$o_s" ||
		return 0
}

save() {
	[[ -f $1 ]] && 
		{ __debug "File already exists."; return 1 } ||
		touch "$1" || 
		{ __debug "Cannot create save file."; return 1 }
	
	local entry
	for entry in "${(@)__buf__}"; do
		entry='.'"$entry"'.'
		print -rn -- "$entry" | base64 | tr --delete '\n' >> $1
		echo >> $1
	done
}

load() {
	[[ -r $1 ]] || 
		{ __debug "Input file does not exist or is unreadable."; return 1 }

	__buf__=()

	local entry
	while IFS=$'\n' read -r entry; do
		local aug="$(print -rn -- "$entry" | base64 -d)"
		aug="${${aug%.}#.}"
		__buf__+=( "$aug" )
	done < "$1" 
}

## Buffer display functions

show() {
	local l=1 r=-1
	local ref="__buf__"
	local cols=()

	[[ $# -gt 0 ]] && {
		l=${@[1]%%,*}
		r=${@[1]##*,}
		ref+='['$l','$r']'
	}

	[[ $# -gt 1 ]] && {
		l=${@[2]%%,*}
		r=${@[2]##*,}
		local seg=("${(@P)ref}")
		local i chunk
		for ((i=1; i <= ${#seg}; i++)); do
			chunk=( "${(@ps:$f_s:)seg[i]}" )
			cols+=( "${(pj:$f_s:)chunk[l,r]}" )
		done
		ref="cols"
	}

	printf -- "%s\n" "${(@P)ref}"
}

inspect() {
	local l=1 r=-1
	local ref="__buf__"
	local cols=()

	[[ $# -gt 0 ]] && {
		l=${@[1]%%,*}
		r=${@[1]##*,}
		ref+='['$l','$r']'
	}

	[[ $# -gt 1 ]] && {
		l=${@[2]%%,*}
		r=${@[2]##*,}
		local seg=("${(@P)ref}")
		local i chunk
		for ((i=1; i <= ${#seg}; i++)); do
			chunk=(${(ps:$f_s:)seg[i]})
			cols+=( "${(pj:$f_s:)chunk[l,r]}" )
		done
		ref="cols"
	}

	print "Inspecting buffer contents: "
	printf -- "%s\n" "${(@P)ref}"
	print "Press q to exit pipeline or any other key to continue."
	local key
	read -krs key
	[[ $key = q ]] && {print "Exiting pipeline."; return 2}
	return 0
}

sflow() {
	local __pipe__='⇝' __lsep__='↦' __rep__='➭:'
	local __llit__='«' __rlit__='»'
	local __lque__='⟦' __rque__='⟧'
	
	local prop=${@:-'1/3'}
	local xy=(${(s:/:)prop})
	local sz=(${(@on)__buf__})
	sz=${#${sz[-1]}}

	local csiz=$[$xy[1]*$(tput cols)/($xy[2]*$sz)]
	local bf="${(pj:$f_s:)__buf__}"
	
	⛥ enter '«$bf»' ⇝ expand \
		⇝ map extract '«(-?\d*\.?\d+)➭:>($match[1])»' \
		⇝ pad x$csiz '«─»' \
		⇝ segment /$csiz \
		⇝ transpose \
		⇝ filter out omitting '«\d+»' \
		⇝ denull \
		⇝ align \
		⇝ suffix ─┐ \
		⇝ group 1,1 2,-1 \
		⇝ partmap 1 prefix '«  »' \
		⇝ partmap 2 prefix '«└─»' \
		⇝ unify \
		⇝ map x '«local c=$(($#x-1)) y=┌; y=${(pr:$c::─:)y}; y+=┘; x=$x$nl$y»' \
		⇝ map regex_replace '« ➭:─»' \
		⇝ act 1:x '«x="├──"${x##──>}»' \
		⇝ act -1:y '«y="${y%%┐*}┤"»' \
		⇝ out
	return 0
}

## Buffer counting functions

count() {
	__buf__=${#__buf__}
}

fcount() { #Assumes rectangular table; record interpretation
	local spl=("${(@ps:$f_s:)__buf__[1]}")
	__buf__=($#spl)
}

countpart() { #Does not see nested partitions
	local ag=("${(@M)__buf__:#$1:*}")
	__buf__=($#ag)
}

partscount() { #Does not see nested partitions
	local __pipe__='⇝' __lsep__='↦'
	local __llit__='«' __rlit__='»'

	__buf__=$( printf -- "${(pj:$i_s:)__buf__}" | \
		synth foldparts lambda x y ↦ '«printf -- $x»' \
		⇝	out )
	__buf__=( ${(ps:$i_s:)__buf__} )
	__buf__=($#__buf__)
}

## Buffer populating functions

detect() {
	setopt local_options extended_glob
	local quals='(#qN)'
	local dir=${(e)__literal__:-'./*'}
	local params="$*"

	fformats	#See Component functions
	dir+=$quals
	__buf__+=($~dir)
}

seql() {
	local b e s

	case $# in
		0) 	b=1; e=10; s=1 ;;
		1) 	b=1; e=$1; s=1 ;;
		2) 	b=$1; e=$2; s=1 ;;
		3) 	b=$1; e=$2; s=$3 ;;
		*) 	__debug "Invalid number of arguments in seql."
				return 1 ;;
	esac

	__buf__=({$b..$e..$s})
}

enter() {
		__buf__=( "${(@e)__literal__-$@}" )
}

## Direct buffer modification

unique() { __buf__=("${(@u)__buf__}") }

elide() {
	setopt local_options noglob
	case $1 in
		'l+') __buf__=("${(@p)__buf__##$~__literal__}") ;;
		'r+') __buf__=("${(@p)__buf__%%$~__literal__}") ;;
		'l-') __buf__=("${(@p)__buf__#$~__literal__}") ;;
		'r-') __buf__=("${(@p)__buf__%$~__literal__}") ;;
		*) __debug "Unknown elision directive."
				return 1 ;;
	esac
}

powerset() {
	local del=${__literal__:-${@[1]:-$f_s}}
	__buf__=( "${(@u)__buf__}" )
	local ct=$#__buf__
	local i j po=('')
	local P=$[2**$ct]
	local newen=''

	for ((i=1; i < $P; i++)); do
		newen=''
		bins=${$(([#2]i))#2#}
		bins=${(pl:$ct::0:)bins}
		for ((j=1; j <= $ct; j++)); do
			[[ $bins[j] -eq 1 ]] &&
				newen+="$__buf__[j]""$del"
		done
		newen="${newen%$del}"
		po+=("$newen")
	done

	__buf__=("${(@)po}")
}

duplicate() {	__buf__+=( "${(@)__buf__}" ) }

denull() {
	__buf__=($__buf__)
}

Unbox() {
	[[ -r $__buf__ ]] ||
		{ __debug "Unbox failed to read ${(q)__buf__}."; return 1 }
	__buf__="$mapfile[$__buf__]"
	__buf__="${__buf__%${nl}}"
	[[ $@ =~ 'e|a' ]] && __buf__=("${(@ps:$i_s:)__buf__}") || return 0
}

vswap() {
	local tmp=$__buf__[$1]
	local smp=$__buf__[$2]
	__buf__[$1]=$smp
	__buf__[$2]=$tmp
}

concat() { 
	local sep=${(e)__literal__-$1}
	__buf__=("$__buf__[1]$sep$__buf__[2]"); 
}

encode_all() {
	local i
	for ((i=1; i <= ${#__buf__}; i++)); do
		__buf__[i]='.'"$__buf__[i]"'.'
		__buf__[i]=$( print -rn -- "$__buf__[i]" | base64 | tr --delete '\n' )
	done
}

decode_all() {
	local i
	for ((i=1; i <= ${#__buf__}; i++)); do
		__buf__[i]="$( print -rn -- "$__buf__[i]" | base64 -d )"
		__buf__[i]="${${__buf__[i]%.}#.}"
	done
}

byfield() {
	local field=$1
	local spl=( "${(@ps:$f_s:)__buf__}" )
	__buf__="$( print -rn -- "$spl[$field]" | base64 | tr --delete '\n' )"
}

randomfill() {
	local entries=${@[1]:-10} chars=${@[2]:-20}
	repeat $entries do
		__buf__+=($(tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~'\
			</dev/urandom | head -c $chars; echo))
	done
}

enumerate() {
	local i
	for ((i=1; i <= ${#__buf__}; i++)); do
		__buf__[$i]="$i"$f_s"$__buf__[$i]"
	done
}

transpose() {
	local rows=$#__buf__
	local entry col_arr=()
	local row_size="${(@ws:$f_s:)#__buf__[1]}"

	for entry in "${(@)__buf__}"; do
		[[ "${(@ws:$f_s:)#entry}" -eq $row_size ]] ||
			{ __debug "Not a rectangular table."; return 1 }
		col_arr+=( "${(@ps:$f_s:)entry}" )
	done

	__buf__=( "${(@)col_arr}" )
	segment $rows $f_s
}

zip() {
	[[ $[ ${#__buf__} % 2 ] -ne 0 ]] && 
		{ __debug "Cannot zip odd-sized buffer."; return 1 }

	local half=$[ ${#__buf__} / 2 ]
	local fi=("${(@)__buf__[1,half]}")
	local se=("${(@)__buf__[half+1,-1]}")
	__buf__=("${(@)fi:^se}")
}

unzip() {
	[[ $[ ${#__buf__} % 2 ] -ne 0 ]] && 
		{ __debug "Cannot unzip odd-sized buffer."; return 1 }

	local evar=() odar=()
	local i sz=$#__buf__

	for ((i=1; i <= $sz; i+=2)); do 
		odar+=( "$__buf__[i]" )
		evar+=( "$__buf__[i+1]" )
	done

	__buf__=( "${(@)odar}" "${(@)evar}" )
}

extract() {
	local non=''
	[[ ! $__literal__ ]] &&
		{ __debug "Literal is necessary for extract."; return 1 }
	
	[[ $@ =~ 'or (.+)$' ]] && non=$match[1] 

	[[ $__literal__ =~ $__rep__ ]] && {
		local spl=( "${(@ps.$__rep__.)__literal__}" )
		[[ $__buf__ =~ ${~spl[1]} ]] && {
			__buf__=( "${(@e)spl[2]}" ) 
		} || {
			__buf__=( "$non" )
		}	
	} || {
		[[ $__buf__ =~ ${~__literal__} ]] && {
			__buf__=("${(@pj:$f_s:)MATCH}") 
		} || {
			__buf__=( "$non" )
		}
	}
}

expand() {
	local sep="${${(e)__literal__-$1}:-$f_s}"
	__buf__=( ${(@ps:$sep:)__buf__} )
}

contract() {
	local sep="${${(e)__literal__-$1}:-$f_s}"
	__buf__=( "${(pj:$sep:)__buf__[@]}" )
}

Separate() {
	local typ=$1
	shift
	local j
	local __bufstr__=""
	local __buf_copy__="${__buf__[@]}"
	case $typ in
		bysize)
			local sizes=($@) segments=(0)
			local nfields=$#sizes
			for j in $sizes; do
				segments+=( $(( segments[-1] + j )) )
			done
			for ((j=2; j<=$#segments; j++)) do
				__bufstr__+=$f_s"$__buf_copy__[$segments[j-1]+1,$segments[j]]"
			done
			__bufstr__="${__bufstr__#$f_s}"
			__buf__=( "$__bufstr__" )
		;;
		byrange)
			local ranges=($@)
			for j in $ranges; do
				__debug "range: $j"
				eval '__bufstr__+=$f_s"$__buf_copy__['$j']"'
			done
			__bufstr__="${__bufstr__#$f_s}"
			__buf__=( "$__bufstr__" )
		;;
		bysep)
			[[ ! $__literal__ ]] &&
				{ __debug "Separators must be put in literal brackets."; return 1 }
			local IFS=$__literal__
			__buf__=( $=__buf_copy__ ); __buf__=( $__buf__ )
		;;
		bystr)
			local sep=${${__literal__-$@}:-$f_s}
			__buf__=( "${(@ps:$sep:)__buf_copy__}" )
	esac
}

dissolve() {
	local dist=() i

	local st="${(@j::)__buf__}"

	for ((i=1; i <= ${#st}; i++)); do
		dist+=( "$st[i]" )
	done
	__buf__=( "${(@)dist}" )
}

prefix() {
	local sp="${(e)__literal__-$*}"
	__buf__=("$sp"${^__buf__}) 
}

suffix() {
	local sp="${${(e)__literal__-$*}:-$f_s}"
	__buf__=(${^__buf__}"$sp") 
}

group() {
	local groups=($@)
	local tmp=() __buf_return__=()
	local i l r

	for ((i=1; i <= ${#groups}; i++)); do
		l=${groups[$i]%%,*}
		r=${groups[$i]##*,}
		tmp=( "${(@)__buf__[l,r]}" )
		tmp=( "$i:"${^tmp} )
		__buf_return__+=( "${(@)tmp}" )
	done
	__buf__=( "${(@)__buf_return__}" )
}

segment() {
	local columns row i j del
	local __buf_size__=$#__buf__
	local __buf_return__=()

	[[ $1 =~ '^(/?)\d+$' ]] &&
		{ columns=$1; shift } ||
		columns=$( best_fit $__buf_size__ )

	[[ $columns =~ '/' ]] && {
		columns=${columns##/}
		columns=$[__buf_size__ / columns]
	}
	
	del=${(e)__literal__-${@[1]:-$f_s}}

	[[ $[ __buf_size__ % columns ] -ne 0 ]] &&
		{ __debug "Buffer indivisible by column number."; return 1 }

	local rows=$[ __buf_size__ / columns ]

	for ((j=1; j <= $rows; j++)); do
		row="$__buf__[j]"
		for ((i=1; i < $columns; i++)); do
			row="$row""$del""$__buf__[ i*rows + j ]"
		done
		__buf_return__+=( "$row" )
	done
	__buf__=( "${(@)__buf_return__}" )
}

unify() { #To aggregate a partitioned buffer
	local __buf_copy__=()
	for entry in "${(@)__buf__}"; do
		[[ $entry =~ '[^\:]+\:([\S\s]*)' ]] && __buf_copy__+=( "$match[1]" )
	done
	__buf__=( "${(@)__buf_copy__}" )
}

partialsum() {
	local __buf_size__=$#__buf__
	[[ $__buf_size__ -lt 2 ]] && return 0;
	
	local sep=${(e)__literal__-${@[1]:-$f_s}}
	local __buf_return__=() i
	local entry="$__buf__[1]"

	__buf_return__+=( "$entry" )

	for ((i=2; i <= $__buf_size__; i++)); do
		entry+="$sep""$__buf__[i]"
		__buf_return__+=( "$entry" )
	done
	__buf__=( "${(@)__buf_return__}" )
}

reverse() {	
	__buf__=( "${(@Oa)__buf__}" )
}

prepend_raw() {
	__buf__=( "${__literal__-$@}" "${(@)__buf__}" )
}

prepend() {
	__buf__=( "${(e)__literal__-$@}" "${(@)__buf__}" )
}

append_raw() {
	__buf__=( "${(@)__buf__}" "${__literal__-$@}" )
}

append() {
	__buf__=( "${(@)__buf__}" "${(e)__literal__-$@}" )
}

lshift() {
	local count=${@[1]:-1}
	local bc=${#__buf__}

	[[ $bc -le $count ]] && { __buf__=(); return 0 }
	[[ $count -lt 0 ]] && count=$[ bc + count ]
	(( ++count ))
	__buf__=( "${(@)__buf__[count, -1]}" )
}

rshift() {
	local count=${@[1]:-1}
	local bc=${#__buf__}

	[[ $bc -le $count ]] && { __buf__=(); return 0 }
	[[ $count -lt 0 ]] && count=$[ -count ] || count=$[ bc - count ]

	__buf__=( "${(@)__buf__[1, count]}" )
}

rotate() {
	local en count=${@[1]:-1}

	if [[ $count -gt 0 ]]; then
		count=$[count % ${#__buf__}]
		__buf__=( "${(@)__buf__[count+1,-1]}" "${(@)__buf__[1,count]}" )
	elif [[ $count -lt 0 ]]; then
		count=$[ ${#__buf__} - ( (-count) % ${#__buf__} ) ]
		__buf__=( "${(@)__buf__[count+1,-1]}" "${(@)__buf__[1,count]}" )
	fi
}

act() {
	local entries=() outent

	[[ $1 =~ '\+(\d+)' ]] && {	repeat $match[1] __buf__+=(""); shift }

	while [[ $1 =~ '(-?\d+):(\w+)' ]] do
		entries+=( $1 )
		eval 'local $match[2]=$__buf__[$match[1]]'
		shift
	done

	local __exec_string__="${__literal__:-$@}"

	eval "$__exec_string__" || 
		{ __debug "Error in act eval."; return 1 }

	while [[ $entries ]]; do
		outent=( "${(@s.:.)entries[1]}" )
		__buf__[$outent[1]]=${(P)outent[2]}
		shift entries
	done
}

pad() {
	[[ $1 =~ 'x(\d+)' ]] &&
		local sur=$[ $match[1] - ( ${#__buf__} % $match[1] ) ] ||
		local sur=$1
	repeat $sur __buf__+="${__literal__-$2}"
}

align() {
	local __pipe__='⇝' __lsep__='↦'
	local __llit__='«' __rlit__='»'
	local __lque__='⟦' __rque__='⟧'
	local __rep__='➭:'

	local fs=( "${(@ps:$f_s:)__buf__[1]}" )
	local nfs=$#fs 

	local leeway=2 maxsize
	[[ $@ =~ 'gap:(\d+)' ]] && leeway=$match[1]
	[[ $@ =~ 'max:(\d+)' ]] && maxsize=$match[1]

	local sizes=() cop=() i=1 tmp='' del=$wh
	local saved=( "${(@)__buf__}" )

	for ((i=1; i <= $nfs; i++)); do
		tmp=''
		keep $i
		cop=("${(@)__buf__}")
		⛥ enter '«${(@)cop}»'\
			⇝	expand '«$f_s»'\
			⇝	map x '«x=${#x}»' \
			⇝ qsort num \
			⇝ lshift -1 \
			⇝ publish tmp
		sizes[i]=$tmp
		[[ $maxsize && ( $sizes[i] -gt $maxsize ) ]] &&
			sizes[i]=$maxsize
		__buf__=("${(@)saved}")
	done
	unset tmp
	local j=1 outarr=()
	for ((j=1; j <= $nfs; j++)); do
		sizes[j]=$[ $sizes[$j] + $leeway ]
		__buf__=("${(@)saved}")
		keep $j
		for ((i=1; i <= $#__buf__; i++)); do
			local jes=${__buf__[i]}
			[[ $maxsize && ( ${#jes} -gt $maxsize ) ]] &&
				__buf__[i]=${${__buf__[i]}[1,$maxsize-2]}".."
			outarr[i]+="${(pr:$sizes[j]::$del:)__buf__[i]}"
		done
	done
	__buf__=("${(@)outarr}")
}

## Search and replace functions on buffer

regex_replace() {
	setopt local_options noglob
	local strings=()
	local cop
	if [[ -n $__literal__ ]]; then
			strings=(${(ps.$__rep__.)__literal__})
			regexp-replace __buf__ "${(e)strings[1]}" "${strings[2]}"
			return 0
	else
			regexp-replace __buf__ "$1" "$2"
			return 0
	fi
}

replace() {
	local strings=()
	local cop
	if [[ -n $__literal__ ]]; then
		if [[ $1 == 'all' ]]; then
			strings=(${(ps.$__rep__.)__literal__})
			__buf__=( "${(@)__buf__//${~strings[1]}/$strings[2]}" )
	 	else
			strings=(${(ps.$__rep__.)__literal__})
			__buf__=( "${(@)__buf__/${~strings[1]}/$strings[2]}" )
		fi	
	else
		if [[ $1 == 'all' ]]; then
			__buf__=( "${(@)__buf__//${~2}/$3}" )
		else
			__buf__=( "${(@)__buf__/${~1}/$2}" )
		fi
	fi
}


## Modifications and replacement functions on records

Over() {
	local fields=() retstr=() i
	local spl=( "${(@ps:$f_s:)__buf__}" )

	[[ $1 == 'all' ]] && 
		{ fields=($( seq "${#${(@ps:$f_s:)__buf__}}" )); shift }

	while [[ $1 =~ '^(-?)\d+$' ]]; do
		fields+=( $1 )
		shift
	done

	[[	! $functions[$1] && ! $aliases[$1] ]] &&
		local __exec_string__="${__literal__//$1/__buf__[1]}" ||
		local __exec_string__="$@"

	for i in $fields; do
		__buf__=( "$spl[i]" )
		eval "$__exec_string__" || 
			{__debug  "Error during field eval."; return 1 }
		spl[i]="$__buf__"
	done

	__buf__=( "${(pj:$f_s:)spl[@]}" )
}

Swap() { #record interpretation
	local spl=( "${(@ps:$f_s:)__buf__}" )
	local tmp="$spl[$1]"
	local smp="$spl[$2]"
	spl[$1]="$smp"
	spl[$2]="$tmp"
	__buf__=( "${(pj:$f_s:)spl}" )
}

Keep() {	#record interpretation
	local list=($@) count=$#
	[[ $count -eq 0 ]] && {__buf__=(); return 0}

	local kept=() i
	local spl=( "${(@ps:$f_s:)__buf__}" )

	for i in {1..${#list}}; do 
		[[ $list[$i] -lt 0 ]] && list[$i]=$[ ${#spl} + $list[$i] + 1 ]
	done

	for ((i=1; i <= $count; i++)); do
		kept+=( "$spl[$list[i]]" )
	done

	local retstr="${(pj:$f_s:)kept}"
	__buf__=( "$retstr" )
}

Excise() {	#record interpretation
	local ex=($@)
	[[ ${#ex} -eq 0 ]] && return 0
	
	local kept=() i
	local spl=( "${(@ps:$f_s:)__buf__}" )
	local count=$#spl

	for i in {1..${#ex}}; do 
		[[ $ex[$i] -lt 0 ]] && ex[$i]=$[ $count + $ex[$i] + 1 ]
	done

	local list=({1..$count})
	list=(${list:|ex})

	for i in $list; do
		kept+=( "$spl[$i]" )
	done

	local retstr="${(@pj:$f_s:)kept}"
	__buf__=( "$retstr" )
}

Permute() {	#record interpretation
	local ord=$# perm=($@)
	local spl=( "${(@ps:$f_s:)__buf__}" )

	local in_ord=${#spl}

	[[ $ord -ne $in_ord ]] && 
		{ __debug "Inconsistent permutation: $ord vs $in_ord."; return 1 }

	local p=(${(on)perm}); 	local q="$p[@]"
	local r=({1..$#}); 			local s="$r[@]"
	[[ $q != $s ]] && { __debug "Invalid permutation."; return 1 }

	local temp_arr=()
	local i
	for ((i=1; i <= $ord; i++)); do
		temp_arr+=( "$spl[$perm[i]]" )
	done

	local retstr="${(@pj:$f_s:)temp_arr}"
	__buf__=( "$retstr" )
}

Freplace() { #record interpretation
	local strings=() cop i=$1
	local spl=( "${(@ps:$f_s:)__buf__}" )

	if [[ $__literal__ ]]; then
		cop="$__literal__"
		if [[ $2 == 'all' ]]; then
			strings=(${(ps.$__rep__.)cop})
			spl[$i]=(${spl[$i]//${~strings[1]}/$strings[2]})
	 	else
			strings=(${(ps.$__rep__.)cop})
			spl[$i]=(${spl[$i]/${~strings[1]}/$strings[2]})
		fi	
	else
		if [[ $2 == 'all' ]]; then
			spl[$i]=(${spl[$i]//${~2}/$3})
		else
			spl[$i]=(${spl[$i]/${~1}/$2})
		fi
	fi
	local retstr="${(pj:$f_s:)spl}"
	__buf__=( "$retstr" )
}

Regex_freplace() { #record interpretation
	local strings=() cop i=$1
	local spl=( "${(@ps:$f_s:)__buf__}" )
	local tmpstr=$spl[i]

	shift

	if [[ -n $__literal__ ]]; then
		cop="$__literal__"
		strings=(${(ps.$__rep__.)cop})
		regexp-replace tmpstr $strings[1] $strings[2]
	else
		regexp-replace tmpstr $1 $2
	fi
	spl[i]="$tmpstr"
	local retstr="${(pj:$f_s:)spl}"
	__buf__=( "$retstr" )
}

actF() {
	local fields=() outrec=()
	local spl=( "${(@ps:$f_s:)__buf__}" )
	[[ $1 =~ '\+(\d+)' ]] &&
		{	repeat $match[1] spl+=(""); shift }
	while [[ $1 =~ '(-?\d+):(\w+)' ]] do
		fields+=( $1 )
		eval 'local $match[2]=$spl[$match[1]]'
		shift
	done

	local __exec_string__="${__literal__:-$@}"

	eval "$__exec_string__" || 
		{__debug "Error in field act eval."; return 1}

	while [[ $fields ]]; do
		outrec=( "${(@s.:.)fields[1]}" )
		spl[$outrec[1]]=${(P)outrec[2]}
		shift fields
	done

	local retstr="${(pj:$f_s:)spl}"
	__buf__=( "$retstr" )
}

## Direct execution functions and lambdas

run() {
	[[ $__literal__ ]] ||
		{ __debug "Literal run string not set."; return 1 }
	local __exec_string__="${__literal__//$1/__buf__}"
	eval "$__exec_string__" ||
		{ __debug "Error in run eval."; return 1 }
}

lambda() { 
	local blocks=("${(ps:$__lsep__:)*}")
	local args=(${=blocks[1]}) arg
	local __bc__=$#__buf__

	[[ ${#__buf__} -lt ${#args} ]] && 
		{__debug "Too small buffer size for lambda: $__bc__ vs ${#args}"; return 1}

	for arg in $args; do
		eval 'local '"$arg"'="$__buf__[1]"; shift __buf__' ||
			{__debug "Error in lambda assignment eval."; return 1}
	done

	if [[ $__literal__ ]]; then
		__buf__=( "$(eval "$__literal__")" ) ||
			{__debug "Error in lambda execution eval."; return 1}
	elif [[ $__question__ ]]; then
		evalstr='[[ '"$__question__"' ]] && echo true || echo false'
		__buf__=( "$(eval "$evalstr")" ) ||
			{__debug "Error in lambda execution eval."; return 1}
	else
		__buf__=( "$(eval "$blocks[2]")" ) ||
			{__debug "Error in lambda execution eval."; return 1}
	fi
} 

## Sorting functions

qsort() { # Passing to zsh native sort; fast
	local typ='o'
	[[ $@ =~ 'num' ]] && typ+='n'
	[[ $@ =~ 'ins' ]] && typ+='i'
	[[ $@ =~ 'des' ]] && typ=${typ/o/O}
	eval '__buf__=( "${(@'$typ')__buf__}" )'
}

fsort() { # qsort for tables
	local ind=$1 typ='o' i
	local insort=() sortout=()

	[[ $@ =~ 'num' ]] && typ+='n'
	[[ $@ =~ 'ins' ]] && typ+='i'
	[[ $@ =~ 'des' ]] && typ=${typ/o/O}

	swap 1 $ind

	for ((i=1; i <= ${#__buf__}; i++)); do
		if [[ $f_s == ':' ]]; then
			eval 'insort+=(${__buf__[i][(ws.'$f_s'.)1]})'
		else
			eval 'insort+=(${__buf__[i][(ws:'$f_s':)1]})'
		fi
	done

	eval 'insort=( "${(@'$typ')insort}" )'

	for ((i=1; i <= ${#__buf__}; i++)); do
		local inner=${__buf__[(i)$insort[i]$f_s*]}
		sortout+=( "${__buf__[inner]}" )
		__buf__[inner]=''
	done
	__buf__=( "${(@)sortout}" )
	swap 1 $ind
}

msort() { #use only as last resort; very slow
	local size=${#__buf__}
	[[ size -eq 1 ]] && return 0

	local __exec_str__="${@:-scomp}"
		
	[[ $size -eq 2 ]] && {
		local uns=( "${(@)__buf__}" )
		eval "$__exec_str__" || 
			{ __debug "Error during sort eval."; return 1 }
		[[ $__buf__ = "true" ]] &&
			__buf__=( "${(@)uns}" ) ||
			__buf__=( "$uns[2]" "$uns[1]" )	
		return 0
	}

	[[ $size -le 20 ]] && {
		smallsort
		return 0
	}

	local hpoint=$[ size/2 ]
	
	local left=( "${(@)__buf__[1,hpoint]}" )
	local right=( "${(@)__buf__[hpoint+1,-1]}" )

	__buf__=( "${(@)left}" )
	msort $__exec_str__
	left=( "${(@)__buf__}" )

	__buf__=( "${(@)right}" )
	msort $__exec_str__
	right=( "${(@)__buf__}" )

	local buck=()

	while [[ $left && $right ]]; do
		__buf__=( "$left[1]" "$right[1]" )
		eval "$__exec_str__" || 
			{ __debug "Error during sort eval."; return 1 }

		[[ $__buf__ = "true" ]] &&
			{ buck+=( "$left[1]" ); shift left } ||
			{ buck+=( "$right[1]" ); shift right }
	done

	buck+=( "${(@)left}" "${(@)right}" )
	__buf__=( "${(@)buck}" )
}

## Main query functions

matching() {
	local val=true #empty match is vacuously true
	if ! [[ $__literal__ ]]; then
		local nargs=$#; [[ $nargs -eq 0 ]] && ret val
		local list=($@) i
		for ((i=1; i <= $nargs; i++)); do
			[[ $__buf__ =~ ${~list[$i]} ]] || val=false
		done
	else
		[[ $__buf__ =~ ${~__literal__} ]] || val=false
	fi
	ret val
}

omitting() {
	local val=true 
	if ! [[ -n $__literal__ ]]; then
		local nargs=$#; [[ $nargs -eq 0 ]] && val="false"
	 		#empty omission is vacuously false
		local list=($@) i
		for ((i=1; i <= $nargs; i++)); do
			[[ $__buf__ =~ ${~list[$i]} ]] && val=false
		done
	else
		[[ $__buf__ =~ ${~__literal__} ]] && val=false
	fi
	ret val
}

fmatching() { 
		#this is the tabular version of matching; record interpretation
	lex
	x=( "${(@ps:$f_s:)x}" )

	local val=true #empty match is vacuously true
	local i j list=($@)

	if ! [[ $__literal__ ]]; then
		local nargs=$#; [[ $nargs -eq 0 ]] && ret val
		[[ $((nargs % 2)) -ne 0 ]] && 
			{__debug "Unpaired arguments in match: $@"; return 1}

		for ((i=1; i < $nargs; i+=2)); do
			j=$((i+1))
			[[ $x[list[$i]] =~ $list[$j] ]] || val=false
		done
	else
		list=(${=__literal__})
		local nargs=${#list}; [[ $nargs -eq 0 ]] && ret val
		[[ $((nargs % 2)) -ne 0 ]] && 
			{__debug "Unpaired arguments in match: $list, $nargs"; return 1}

		for ((i=1; i < $nargs; i+=2)); do
			j=$((i+1))
			[[ $x[list[$i]] =~ ${(e)list[$j]} ]] || val=false
		done
	fi
	ret val
}

fomitting() { 
		#this is the tabular version of omits; record interpretation
		#empty omission is vacuously false

	lex
	x=( "${(@ps:$f_s:)x}" )

	local val=false 
	local i j list=($@)

	if ! [[ $__literal__ ]]; then
		local nargs=$#; [[ $nargs -eq 0 ]] && ret val
		[[ $((nargs % 2)) -ne 0 ]] && 
			{__debug "Unpaired arguments in match."; return 1}

		for ((i=1; i < $nargs; i+=2)); do
			j=$((i+1))
			[[ $x[list[$i]] =~ $list[$j] ]] && val=false
		done
	else
		list=(${=__literal__})
		local nargs=${#list}; [[ $nargs -eq 0 ]] && ret val
		[[ $((nargs % 2)) -ne 0 ]] && 
			{__debug "Unpaired arguments in match."; return 1}
		for ((i=1; i < $nargs; i+=2)); do
			j=$((i+1))
			[[ $x[list[$i]] =~ $list[$j] ]] && val=false
		done
	fi
	ret val
}

scomp() {
	[[ $__buf__[1] < $__buf__[2] || $__buf__[1] = $__buf__[2] ]] &&
		__buf__="true" || __buf__="false"
}

ncomp() {
	[[ $__buf__[1] -le $__buf__[2] ]] &&
		__buf__="true" || __buf__="false"
}

Ancomp() {
	[[ $[abs(__buf__[1])] -ge $[abs(__buf__[2])] ]] &&
		__buf__="true" || __buf__="false"
}

## Main arithmetic functions

add() {
	__buf__=$[ $__buf__[1] + $__buf__[2] ]
}

sub() {
	__buf__=$[ $__buf__[1] - $__buf__[2] ]
}

mul() {
	__buf__=$[ $__buf__[1] * $__buf__[2] ]
}

idiv() {
	__buf__=$[ $__buf__[1] / $__buf__[2] ]
}

rem() {
	__buf__=$[ $__buf__[1] % $__buf__[2] ]
}

dist() {
	[[ $__buf__[1] -le $__buf__[2] ]] &&
		__buf__=$[ $__buf__[2] - $__buf__[1] ] ||
		__buf__=$[ $__buf__[1] - $__buf__[2] ]
}

max() {
	[[ $__buf__[1] -le $__buf__[2] ]] && 
		__buf__=$__buf__[2] || 
		__buf__=$__buf__[1]
}

min() {
	[[ $__buf__[1] -le $__buf__[2] ]] && 
		__buf__=$__buf__[1] || 
		__buf__=$__buf__[2]
}

mod() {
	__buf__=$[ __buf__ % $1 ]
}

inc() {__buf__=( $[__buf__+1] )}

square() {__buf__=( $[__buf__*__buf__] )}

invert() {__buf__=($[1.0/__buf__])}

trans() {__buf__=($[$1+__buf__])}

scale() {__buf__=($[$1*__buf__])}

sroot() {__buf__=($[ sqrt(__buf__) ])}

ipow() { 
	local ac="$__buf__"
	[[ $1 -gt 0 ]] && {
		repeat $[$1-1] __buf__=($[__buf__*ac]) } || {
		__buf__=$[1.0/__buf__]
		repeat $[abs($1)-1] __buf__=($[__buf__*(1.0/ac)])
	}
}

pow() { 
	__buf__=($[ ($1)*log(__buf__) ])
	__buf__=($[exp(__buf__)])
}

nroot() {
	__buf__=($[ (1.0/$1)*log(__buf__) ])
	__buf__=($[exp(__buf__)])
}

## Array arithmetic functions

sum() {
	foldl add
}

Kahan_sum() {
	local sz=${#__buf__}
	local i
	local c=0
	local part=0
	local tmp
	local sm=0

	for ((i=1; i <= $sz; i++)); do
		tmp=$[ __buf__[i] - c ]
		part=$[ sm + tmp ]
		c=$[ part - sm ]
		c=$[ c - tmp ]
		sm=$part
	done
	__buf__=($sm)
}

prod(){
	foldl mul
}

mean() {
	local N=${#__buf__}
 local S
	local i
	case $1 in
		A) 
		S=0
			 S=$(__Neumeier_sum __buf__)
			 S=$[S/(N*1.0)]
			;;
		G) S=0
			 local tbuf=()
			 for ((i=1; i<=$N; i++)); do
				 tbuf+=($[log(__buf__[i])])
			 done
			 S=$(__Kahan_sum tbuf)
			 S=$[(1.0/N)*S]
			 S=$[exp(S)]
			;;
		H) S=0
			 local tbuf=()
			 for ((i=1; i<=$N; i++)); do
				 tbuf+=($[1.0/__buf__[i]])
			 done
			 S=$(__Kahan_sum tbuf)
			 S=$[1.0/S]
			 S=$[N*S]
			;;
		F) local __buf_copy__=($__buf__)
			 local tbuf=()
			 local pair=("${(@ps:,:)__literal__}")
			 S=0
			 for ((i=1; i<=$N; i++)); do
				 __buf__=($__buf_copy__[i])
					eval "$pair[1]" ||
						{ __debug "Error during mean eval."; return 1 }
						tbuf+=($__buf__)
			 done
			 S=$(__Kahan_sum tbuf)
			 __buf__=($[(1.0/N)*S])
		 	 eval "$pair[2]" ||
		 	 	 { __debug "Error during mean eval."; return 1 }
			 S="$__buf__"
			__buf__=($S)
			;;
		*) 	__debug "Unknown mean."
				return 1 ;;
	esac
	__buf__=($S)
}

## Main higher order functions

map() {
	local __buf_size__=${#__buf__}
	local __exec_string__="$@"
	local __buf_copy__=("${(@)__buf__}")

	[[ $# -eq 2 &&
		! $functions[$1] &&
		! $aliases[$1] &&
		$__literal__ ]] &&
			__exec_string__=${__literal__//$1/__buf__[1]}

	local entry
	local __buf_return__=()

	for entry in "${(@)__buf_copy__}"; do
		__buf__=( "$entry" )
		eval "$__exec_string__" || {__debug "Error in map eval."; return 1}
		__buf_return__+=( "${(@)__buf__}" )
	done
	__buf__=( "${(@)__buf_return__}" )
}

filter() {
	local __buf_size__=${#__buf__}
	local res="true"
	[[ $1 = 'out' ]] && { res="false"; shift }
	local __exec_string__="$@"
	local __buf_copy__=( "${(@)__buf__}" )
	local entry f_out
	local __buf_return__=()

	if [[ $# -eq 2 &&
		! $functions[$1] &&
		! $aliases[$1] &&
		$__question__ ]]; then

		__question__=${__question__//$1/__buf__[1]}

		for entry in "${(@)__buf_copy__}"; do
			__buf__=( "$entry" )
			eval '[[ '"$__question__"' ]] && f_out="true" || f_out="false"'
			[[ $f_out == $res ]] && __buf_return__+=( "$entry" )
		done
		__buf__=( "${(@)__buf_return__}" )
	else
		for entry in "${(@)__buf_copy__}"; do
			__buf__=( "$entry" )
			eval "$__exec_string__" || 
				{__debug "Error in filter eval."; return 1}
			[[ $__buf__ == $res ]] && 
				__buf_return__+=( "$entry" )
		done
		__buf__=( "${(@)__buf_return__}" )
	fi
}

foldl() {
	local __buf_size__=${#__buf__}
	[[ $__buf_size__ -lt 2 ]] && {__debug "Buffer error in fold."; return 1}
	local __exec_string__="$@"
	local __buf_copy__=( "${(@)__buf__}" )

	local accumulator="$__buf__[1]"
	local entry
	local i
	for ((i=2; i <= $__buf_size__; i++)); do
		entry="$__buf_copy__[i]"
		__buf__=( "$accumulator" "$entry" )
		eval "$__exec_string__" || {__debug  "Error in fold eval."; return 1 }
		accumulator="$__buf__"
	done
}

induce() { # takes f : X -> X and induces
	local i
	[[ $1 =~ '^(-?)\d+$' ]] && { i=$1; shift } || i=1
	local __exec_string__="$@"
	local __buf_return__=()

	if [[ $# -eq 2 &&
		! $functions[$1] &&
		! $aliases[$1] &&
		(-n $__literal__) ]]; then
			__exec_string__=${__literal__//$1/__buf__[1]}
	fi
	__buf_return__=( "${(@)__buf__}" )
	repeat $i do
			eval "$__exec_string__" || {__debug "Error in induction eval."; return 1}
			__buf_return__+=( "${(@)__buf__}" )
	done
	__buf__=( "${(@)__buf_return__}" )
}

fmap() {
	local __buf_copy__=( "${(@)__buf__}" )
	local fields=()
	local nfields=("${(@ps:$f_s:)__buf__[1]}")
	nfields=${#nfields}
	while [[ $1 =~ '^(-?)\d+$' ]]; do
	[[ $1 -gt 0 ]] &&
		fields+=( $1 ) ||
		fields+=( $[$nfields + $1 + 1] )
		shift
	done
	local i
	local __exec_string__="$@"
	
	if [[ $# -eq 2 &&
		! $functions[$1] &&
		! $aliases[$1] &&
		(-n $__literal__) ]]; then
			__exec_string__=${__literal__//$1/__buf__[1]}
	fi

	local entry
	local spl
	local __buf_return__=()

	for entry in "${(@)__buf_copy__}"; do
		spl=( "${(@ps:$f_s:)entry}" )
			for i in $fields; do
				__buf__=( "$spl[i]" )
				eval "$__exec_string__" || { __debug  "Error in field map eval."; return 1 }
				spl[i]="$__buf__[@]"
			done
			__buf_return__+=("${(pj:$f_s:)spl[@]}")
	done
	__buf__=( "${(@)__buf_return__}" )
}

ffilter() {
	local __buf_size__=${#__buf__}
	local __buf_copy__=( "${(@)__buf__}" )

	local res="true"
	[[ $1 = 'out' ]] && { res="false"; shift }

	local fields=()
	local nfields=("${(@ps:$f_s:)__buf__[1]}")
	nfields=${#nfields}

	while [[ $1 =~ '^(-?)\d+$' ]]; do
		[[ $1 -gt 0 ]] &&
			fields+=( $1 ) ||
			fields+=( $[$nfields +$1 + 1] )
		shift
	done

	local i
	local __exec_string__="$@"
	local spl=()
	local retstr=()

	local entry f_out
	local __buf_return__=()

	if [[ $# -eq 2 &&
		! $functions[$1] &&
		! $aliases[$1] &&
		$__question__ ]]; then

		__question__=${__question__//$1/__buf__[1]}
		for entry in "${(@)__buf_copy__}"; do
			local retstr=()
			local accept=1
			spl=( "${(@ps:$f_s:)entry}" )
			for ((i=1; i <= ${#spl}; i++)); do
				if [[ $fields[(r)$i] ]]; then 
					__buf__=( "$spl[i]" )
					eval '[[ '"$__question__"' ]] && f_out="true" || f_out="false"'
					[[ $f_out == $res ]] && retstr+=( "$spl[i]" ) || accept=0
				else
					retstr+=( "$spl[i]" )
				fi
			done
			[[ $accept = 1 ]] &&
				__buf_return__+=( "${(@pj:$f_s:)retstr[@]}" )
		done
		__buf__=( "${(@)__buf_return__}" )

	else
		for entry in "${(@)__buf_copy__}"; do
			local retstr=()
			local accept=1
			spl=( "${(@ps:$f_s:)entry}" )
			for ((i=1; i <= ${#spl}; i++)); do
				if [[ -n $fields[(r)$i] ]]; then 
					__buf__=($spl[i])
					eval "$__exec_string__" || 
						{__debug "Error in field filter eval."; return 1}
					[[ $__buf__ == "true" ]] && retstr+=( "$spl[i]" ) || accept=0
				else
					retstr+=( "$spl[i]" )
				fi
			done
			[[ $accept = 1 ]] &&
				__buf_return__+=( "${(@pj:$f_s:)retstr[@]}" )
		done
		__buf__=( "${(@)__buf_return__}" )
	fi
}

partition() {
	local __buf_size__=${#__buf__}
	local __exec_string__="$@"
	local __buf_copy__=( "${(@)__buf__}" )

	[[ $# -eq 2 &&
		! $functions[$1] &&
		! $aliases[$1] &&
		$__literal__ ]] &&
		__exec_string__=${__literal__//$1/__buf__[1]}

	local tostr
	local entry
	local __buf_return__=()
	for entry in "${(@)__buf_copy__}"; do
		__buf__=( "$entry" )
		eval "${(z)__exec_string__}" || 
			{__debug "Error in partition eval."; return 1}
		tostr="$__buf__[@]"':'"$entry"
		__buf_return__+=( "$tostr" )
	done
	__buf__=( "${(@)__buf_return__}" )
}

reprun() { #buggy
	local __pipe__='⇝' __lsep__='↦'
	local __llit__='«' __rlit__='»'
	local __buf__=$( printf -- "${(pj:$i_s:)__buf__}" | \
		synth foldparts lambda x y ↦ '«printf -- $x»' \
		⇝	out )
	__buf__=( ${(ps:$i_s:)__buf__} )

	local __buf_copy__=(${__buf__//*:/})
	local __exec_string__="$@"
	[[ $__exec_string__ =~ 'lambda|λ' ]] &&
		{ __debug "Lambda in reprun detected; no effect."; return 1 }
	[[ $# -eq 2 &&
		! $functions[$1] &&
		! $aliases[$1] &&
		$__literal__ ]] &&
			__exec_string__=${__literal__//$1/__buf__[1]}
	for entry in "${(@)__buf_copy__}"; do
		__buf__=( "$entry" )
		eval "$__exec_string__" || 
			{__debug "Error in reprun eval."; return 1}
		done
}

partmap() {
	local parts=( ${(ps.:.)@[1]} )
	shift
	local __exec_string__="$@"

	[[ $# -eq 2 &&
		! $functions[$1] &&
		! $aliases[$1] &&
		$__literal__ ]] &&
			__exec_string__=${__literal__//$1/__buf__[1]}

	local __buf_size__=${#__buf__}
	local __buf_copy__=( "${(@)__buf__}" )

	local entry
	local prepared
	local __buf_return__=()

	for entry in "${(@)__buf_copy__}"; do
		__buf__=( "$entry" )
		local pin=$parts[(ri)${entry%:*}]
		if [[ $pin -le ${#parts} ]]; then
			prepared="${entry##$parts[pin]:}"
			__buf__=( "$prepared" )
			eval "$__exec_string__" || 
				{__debug "Error in partmap eval."; return 1}
			__buf__="$parts[pin]:$__buf__[@]"
			__buf_return__+=( "${(@)__buf__}" )
		else
			__buf_return__+=( "$entry" )
		fi
	done
	__buf__=( "${(@)__buf_return__}" )
}

power() {
	local iters=$1
	shift
	local __exec_string__="$@"
	repeat $iters do
		eval "$__exec_string__" || 
			{ __debug "Error in power eval."; return 1 }
	done
}

develop() { #Takes f : X x X -> Y and returns matrix of outputs
	local __buf_size__=${#__buf__}
	local __exec_string__="$@"
	local __buf_copy__=( "${(@)__buf__}" )

	[[ $# -eq 2 &&
		! $functions[$1] &&
		! $aliases[$1] &&
		$__literal__ ]] &&
			__exec_string__=${__literal__//$1/__buf__}

	local xentry yentry
	local __buf_return__=()
	local entry_return
	for xentry in "${(@)__buf_copy__}"; do
		entry_return=''
		for yentry in "${(@)__buf_copy__}"; do
			__buf__=( "$xentry" "$yentry" )
			eval "$__exec_string__" || {__debug "Error in develop eval."; return 1}
			entry_return+="$__buf__[@]""$f_s"
		done
		entry_return="${entry_return%%$f_s}"
		__buf_return__+=( "$entry_return" )
	done
	__buf__=( "${(@)__buf_return__}" )
}

unfold() { # takes f : X -> X x X and induces, interleaving in/out
	local i
	[[ $1 =~ '^(-?)\d+$' ]] && { i=$1; shift } || i=1
	local __exec_string__="$@"
	local __buf_return__=()

	[[ $# -eq 2 &&
		! $functions[$1] &&
		! $aliases[$1] &&
		$__literal__ ]] &&
			__exec_string__=${__literal__//$1/__buf__[1]}

	__buf_return__=( "${(@)__buf__}" )
	repeat $i do
			__buf__=( "$__buf_return__[-1]" )
			eval "$__exec_string__" || 
				{__debug "Error in unfold eval."; return 1}
			__buf_return__[-1]=( "$__buf__[1]"	)
			__buf_return__+=( "$__buf__[2]"	)
	done
	__buf__=( "${(@)__buf_return__}" )
}

graphmap() {
	local __buf_size__=${#__buf__}
	local __exec_string__="$@"
	local __buf_copy__=( "${(@)__buf__}" )

	[[ $# -eq 2 &&
		! $functions[$1] &&
		! $aliases[$1] &&
		$__literal__ ]] &&
			__exec_string__=${__literal__//$1/__buf__}

	local entry
	local __buf_return__=()
	local i
	for ((i=1; i <= $__buf_size__; i++)); do
		__buf__=( $i "$__buf_copy__[i]" )
		eval "$__exec_string__" || 
			{__debug "Error in graphmap eval."; return 1}
			__buf_return__+=( "${(@)__buf__}" )
	done
	__buf__=( "${(@)__buf_return__}" )
}

partfold() {
	local part="$1"':'
	shift
	local __exec_string__="$@"

	local __buf_size__=${#__buf__}
	local __buf_copy__=( "${(@)__buf__}" )
	local __buf_return__=()
	local i=1
	local ind=()
	for ((i=1; i<= $__buf_size__; i++)); do
		[[ $__buf__[i] =~ "^$part" ]] && ind+=( $i )
	done
	[[ ${#ind} -lt 2 ]] && return 0
	local accumulator="$__buf__[$ind[1]]"
	accumulator="${accumulator##$part}"
	shift ind
	local entry

	for i in $ind; do
		entry="$__buf_copy__[i]"
		prepared="${entry##$part}"
		__buf__=( "$accumulator" "$prepared" )
		eval "$__exec_string__" || 
			{__debug  "Error in partition fold eval."; return 1 }
		accumulator="$__buf__"
	done

	for ((i=1; i<= $__buf_size__; i++)); do
		if [[ $i -ne $ind[-1] ]]; then
			if ! [[ "$__buf_copy__[i]" =~ "^$part" ]]; then
				__buf_return__+=( "$__buf_copy__[i]" )
			fi
		else
			__buf_return__+=( "$part""$accumulator" )
		fi
	done
	__buf__=( "${(@)__buf_return__}" )
}

foldparts() {
	local __exec_string__="$@"
	local parts=()
	local __buf_size__=${#__buf__}
	local i
	for ((i=1; i <= $__buf_size__; i++ )); do
		[[ $__buf__[i] =~ "^([^:]+)\:" ]] &&
			parts+=( "$match[1]" )
	done
	parts=( "${(@u)parts}" )
	local entry
	for entry in "${(@)parts}"; do
		partfold "$entry" "$__exec_string__"
	done
}

Prepend() {
	local ref="@"
	[[ $__literal__ ]] && ref="__literal__"
	local buf=( "${(@)__buf__}" )
	[[ -f ${(P)ref} ]] && {
		load ${(P)ref}
			__buf__=( "${(@)__buf__}" "${(@)buf}" )
	} || {
		#${(ezP)ref} 2>/dev/null || __buf__=("${(@aP)ref}") # too risky
		__buf__=("${(@ezP)ref}")
		__buf__=( "${(@)__buf__}" "${(@)buf}" )
	}
}

Append() {
	local ref="@"
	[[ $__literal__ ]] && ref="__literal__"
	local buf=( "${(@)__buf__}" )
	[[ -f ${(P)ref} ]] && {
		load ${(P)ref}
		__buf__=( "${(@)buf}" "${(@)__buf__}" )
	} || {
		#${(ezP)ref} 2>/dev/null || __buf__=("${(@ezP)ref}") $too risky
		__buf__=("${(@ezP)ref}")
		__buf__=( "${(@)buf}" "${(@)__buf__}" )
	}
}

## Main loop

synth() {
	local nblocks=1 divide=0
	typeset -A Array
	[[ $1 =~ '--byblocks' ]] && { divide=1; shift }
	local __parameters__="${@//$'\\\n'/ }"
	local __comands__=("${(@ps/$__pipe__/)__parameters__}")				
	local __comand_count__=${#__comands__}
	local __commands__=()
	local i rep strr strm

	for ((i=1; i <= __comand_count__; i++)); do
		[[ $__comands__[i] =~ '⁇(\w+)' ]] && {
			#__debug "Detected mock candidate: $match[1]"
			[[ $functions[$match[1]] ]] && {
				local repstr=$__comands__[i]
				regexp-replace repstr '⁇(\w+)' "$match[1]"
				__comands__[i]="$repstr"
			} || {
			#	__debug "Candidate is unknown. Mocking $match[1]"
				local repstr=$__comands__[i]
				regexp-replace repstr '⁇(\w+)' 'mock '"$match[1]"
				__comands__[i]="$repstr"
			}
		}
	done

	for ((i=1; i <= __comand_count__; i++)); do
		if [[ $__comands__[$i] =~ 'loop (\d+)' ]]; then
			strr=$__comands__[$i]
			strr=${strr//$MATCH}
			for ((rep=1; rep <= $match[1]; rep++)); do
				__commands__+=( $strr )
			done
		else
				__commands__+=( $__comands__[$i] )
		fi
	done

	local __command_count__=${#__commands__}
	local __buf__=()
	local bin=''
	[[ $divide -eq 0 ]] && {
		while IFS= read -r -d $i_s bin; do
			__buf__+=($bin)
		done
	} || {
		i=0
		while IFS= read -r -d $i_s bin; do
			(( ++i ))
			Array[$((1+(i-1)/$__block_size__))]+="$bin"$i_s
		done
		nblocks=$[ i / __block_size__ ]
		[[ $[ i % __block_size__ ] -ne 0 ]] && (( ++nblocks ))
	}

	local __buf_size__=${#__buf__}
	local __exec_string__
	local __literal__
	local __question__
	local errst=0
	
	for ((j=1; j<= $nblocks; j++)); do
	[[ $divide -ne 0 ]] && { Array[$j]=${Array[$j]%$i_s}; __buf__=("${(ps:$i_s:)Array[$j]}")}
	for ((i=1; i <= __command_count__; i++)); do

		unset __literal__
		unset __question__

		__exec_string__="${__commands__[i]#"${__commands__[i]%%[![:space:]]*}"}"
		__exec_string__="${__exec_string__%"${__exec_string__##*[![:space:]]}"}" 

		[[ $__exec_string__ =~ $__llit__ ]] && {
			__literal__="${__exec_string__##*$__llit__}"
			__literal__="${__literal__%%$__rlit__*}"
 			__exec_string__="${__exec_string__/$__llit__*$__rlit__/__token__}" 
		}

		[[ $__exec_string__ =~ '⫽' ]] && {
			__literal__="${__exec_string__#*⫽}"
			__literal__="${__literal__%⫽*}"
			__literal__="${__literal__/⫽/$__rep__}"
 			__exec_string__="${__exec_string__/⫽*⫽/__token__}" 
		}

		[[ $__exec_string__ =~ $__lque__ ]] && {
			__question__="${__exec_string__##*$__lque__}"
			__question__="${__question__%%$__rque__*}"
 			__exec_string__="${__exec_string__/$__lque__*$__rque__/_question_}" 
		}

		eval "$__exec_string__" || errst=$?

		[[ $errst == 1  || $errst -gt 2 ]] &&
			{__debug "Eval fail in main loop at command $i."; return 1}
		[[ $errst == 2 ]] &&
			{__debug "Inspection terminated pipeline after command $((i-1))."; return 0}
	done
	done
}

# exper() { #testing
# 	local block_size=1000
# 	local __exec_string__='<<(print -rn -- $total[$j]) '"$@"
# 	typeset -A total
# 	local i=0 j
# 	local bin=''
# 	while IFS= read -r -d $i_s bin; do
# 		(( ++i ))
# 		total[$((1+(i-1)/block_size))]+="$bin"$i_s
# 	done
# 	local nblocks=$[ i / block_size ]
# 	[[ $[ i % block_size ] -ne 0 ]] && (( ++nblocks ))
# 	for ((j=1; j<=$nblocks; j++)); do
# 		eval "${__exec_string__}"
# 	done
# }

## Component functions

seedis() { printf $i_s } # For piping empty state to synth; deprecated.

best_fit() { # Component in segment
	local X=$1
	local S=sqrt($X)
	local low_divisors=( 1 )
	for ((i=2; i <= $S; i++)); do
		[[ $[X % i] -eq 0 ]] &&
			 low_divisors+=( $i )
	done
	print $[ X / low_divisors[-1] ]
}

fformats(){ #Component in detect()
	typeset -A fl
	fl[N]='^'
	fl[L]='-'
	fl[LN]='-^'
	fl[NL]='^-'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?dir' ]] && quals+='(#q'${fl[$match[2]]}'/)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?full(?:dir)?' ]] && quals+='(#q'${fl[$match[2]]}'F)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?reg(?:ular)?' ]] && quals+='(#q'${fl[$match[2]]}'.)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?soc(?:ket)?' ]] && quals+='(#q'${fl[$match[2]]}'=)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?fifo' ]] && quals+='(#q'${fl[$match[2]]}'p)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?dev(?:ice)?' ]] && quals+='(#q'${fl[$match[2]]}'%)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?link' ]] && quals+='(#q'${fl[$match[2]]}'@)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?EXE' ]] && quals+='(#q'${fl[$match[2]]}'*)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?blsp' ]] && quals+='(#q'${fl[$match[2]]}'%b)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?chsp' ]] && quals+='(#q'${fl[$match[2]]}'%c)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?r(?:ead)?' ]] && quals+='(#q'${fl[$match[2]]}'r)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?w(?:rite)?' ]] && quals+='(#q'${fl[$match[2]]}'w)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?e(?:xec)?' ]] && quals+='(#q'${fl[$match[2]]}'x)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?gr(?:ead)?' ]] && quals+='(#q'${fl[$match[2]]}'A)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?gw(?:rite)?' ]] && quals+='(#q'${fl[$match[2]]}'I)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?ge(?:xec)?' ]] && quals+='(#q'${fl[$match[2]]}'E)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?wr(?:ead)?' ]] && quals+='(#q'${fl[$match[2]]}'R)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?ww(?:rite)?' ]] && quals+='(#q'${fl[$match[2]]}'W)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?we(?:xec)?' ]] && quals+='(#q'${fl[$match[2]]}'X)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?setuid' ]] && quals+='(#q'${fl[$match[2]]}'s)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?setgid' ]] && quals+='(#q'${fl[$match[2]]}'S)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?sticky' ]] && quals+='(#q'${fl[$match[2]]}'t)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?ondev (\S+)' ]] && quals+='(#q'${fl[$match[2]]}'d'$match[3]')'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?size (\S+)' ]] && quals+='(#q'${fl[$match[2]]}'L'$match[3]')'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?nlinks (\S+)' ]] && quals+='(#q'${fl[$match[2]]}'l'$match[3]')'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?lastacc (\S+)' ]] && quals+='(#q'${fl[$match[2]]}'a'$match[3]')'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?lastmod	(\S+)' ]] && quals+='(#q'${fl[$match[2]]}'m'$match[3]')'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?lastinode (\S+)' ]] && quals+='(#q'${fl[$match[2]]}'c'$match[3]')'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?lastwrite (\S+)' ]] && quals+='(#q'${fl[$match[2]]}'c'$match[3]')'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?onlinks' ]] && quals+='(#q'${fl[$match[2]]}'-)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?dot' ]] && quals+='(#q'${fl[$match[2]]}'D)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?mine' ]] && quals+='(#q'${fl[$match[2]]}'U)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?mygroup' ]] && quals+='(#q'${fl[$match[2]]}'G)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?owner (\w+)' ]] && quals+='(#q'${fl[$match[2]]}'u:'$match[3]':)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?group (\w+)' ]] && quals+='(#q'${fl[$match[2]]}'g:'$match[3]':)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?stopat (\d+)' ]] && quals+='(#q'${fl[$match[2]]}'Y'$match[3]')'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?sort:name' ]] && quals+='(#q'${fl[$match[2]]}'on)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?sort:size' ]] && quals+='(#q'${fl[$match[2]]}'oL)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?sort:links' ]] && quals+='(#q'${fl[$match[2]]}'ol)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?sort:lastacc' ]] && quals+='(#q'${fl[$match[2]]}'oa)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?sort:lastmod' ]] && quals+='(#q'${fl[$match[2]]}'om)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?sort:lastinode' ]] && quals+='(#q'${fl[$match[2]]}'oc)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?dsort:name' ]] && quals+='(#q'${fl[$match[2]]}'On)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?dsort:size' ]] && quals+='(#q'${fl[$match[2]]}'OL)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?dsort:links' ]] && quals+='(#q'${fl[$match[2]]}'Ol)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?dsort:lastacc' ]] && quals+='(#q'${fl[$match[2]]}'Oa)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?dsort:lastmod' ]] && quals+='(#q'${fl[$match[2]]}'Om)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?dsort:lastinode' ]] && quals+='(#q'${fl[$match[2]]}'Oc)'
	[[ $params =~ '(?:^|\s)(\d+),(\d*)' ]] && quals+='(#q['$match[1]','${match[2]:-"-1"}'])'
	[[ $params =~ '(^|\s)abs' ]] && quals+='(#q:a)'
	[[ $params =~ '(^|\s)path' ]] && quals+='(#q:P)'
	[[ $params =~ '(^|\s)linkabs' ]] && quals+='(#q:A)'
	[[ $params =~ '(^|\s)ext' ]] && quals+='(#q:e)'
	[[ $params =~ '(^|\s)root' ]] && quals+='(#q:r)'
	[[ $params =~ '(^|\s)lower' ]] && quals+='(#q:l)'
	[[ $params =~ '(^|\s)upper' ]] && quals+='(#q:u)'
	[[ $params =~ '(^|\s)head (\d+)' ]] && quals+='(#q:h'$match[2]')'
	[[ $params =~ '(^|\s)tail (\d+)' ]] && quals+='(#q:t'$match[2]')'
	[[ $params =~ '(^|\s)quoted' ]] && quals+='(#q:q)'
}

smallsort() { # Component in msort, use with smol arrays
	local iter=( "${(@)__buf__}" )
	local sor=( "$iter[1]" )
	shift iter
	while [[ $iter ]]; do
		local i=$[${#sor}+1]
		while ((i--)); do
			[[ $i -eq 0 ]] && {
				sor=($iter[1] $sor)
				break
			}
			
			__buf__=( "$sor[i]" "$iter[1]" )
			eval "$__exec_str__" || { __debug "Error during sort eval."; return 1 }

			[[ $__buf__ = "true" ]] && {
				sor=( "${(@)sor[1,i]}" "$iter[1]" "${(@)sor[i+1,-1]}" )
				break
			}
		done
		shift iter
	done
	__buf__=( "${(@)sor}" )
}

__Kahan_sum() {
	local __buf__=("${(@ps: :P)@}")
	local sz=${#__buf__}
	msort Ancomp
	local i
	local c=0
	local part=0
	local tmp
	local sm=0

	for ((i=1; i <= $sz; i++)); do
		tmp=$[ __buf__[i] - c ]
		part=$[ sm + tmp ]
		c=$[ part - sm ]
		c=$[ c - tmp ]
		sm=$part
	done
	print "$sm"
}

__Neumeier_sum() {
	local __buf__=("${(@ps: :P)@}")
	local sz=${#__buf__}
	local i
	local c=0
	local part=0
	local tmp
	local sm=0

	for ((i=1; i <= $sz; i++)); do
		tmp=$[ sm + __buf__[i] ]
		[[ $[abs(sm)] -ge $[abs(__buf__[i])] ]] && 
			c=$[ c + (sm - tmp) + __buf__[i] ] ||
			c=$[ c + (__buf__[i] - tmp) + sm ]
		sm=$tmp
	done
	[[ $c -ne 0 ]] && print "Neumeier compensation: $c" >&2
	sm=$[sm+c]
	print "$sm"
}

prod(){
	foldl mul
}

## Emit function; try not to use this

emit() {
	local i=$1
	local entry
	[[ $i -lt 0 ]] && i=$(( ${#__buf__} + $i + 1 ))
	entry="$__buf__[$i]"
	local j=0
	shift
	[[	! $functions[$1] && ! $aliases[$1] ]] && {
		j=$1
		shift
		entry=( "${(@ps:$f_s:)entry}" )
		entry="$entry[$j]"
	}
	__exec_string__="$@"
	if [[ -n $__literal__ ]]; then
		__literal__=${__literal__//ψ/${(q)entry}}
	else
		__exec_string__=${__exec_string__//ψ/${(q)entry}}
	fi
	eval "$__exec_string__" || 
		{__debug "Error during emit eval.\n"; return 1}
}

# Bindings and codes

## Unicode key bindings
bindkey -s "\`,," \'«
bindkey -s "\`.." »\'
bindkey -s "\`p" " ⇝ "
bindkey -s "\`w" " ➢ " 
bindkey -s "\`W" " ⇶ " 
bindkey -s "\`\\" " | ➢ " 
bindkey -s "\`o" "◎ " 
bindkey -s "\`O" "◍ " 
bindkey -s "\`x" "•\|➢ "
bindkey -s "\`l" "λ "
bindkey -s "\`m" " ↦ "
bindkey -s "\`1" "'«»'ODOD"
bindkey -s "\`2" "'⟦⟧'ODOD"
bindkey -s "\`q" "⛥ "
bindkey -s "\`r" "➭:"
bindkey -s "\`t" "ψ"
bindkey -s "\`x" "χ"
bindkey -s "\`?" "⁇"
bindkey -s "\`g" "ℜ"
bindkey -s "\`" " \\\\ ⇝ "
bindkey -s "\`/" "'⫽⫽⫽'ODODOD"
### Note: These need to be changed if you change the symbols in the
### preamble!

## Code table for unicode keys used

### « is 0x00ab
### » is 0x00bb
### ⇝ is 0x21dd
### ➢ is 0x27a2
### • is 0x2022
### ◎ is 0x25ce
### ⟦ is 0x27e6
### ⟧ is 0x27e7
### ➭ is 0x27ad
### λ is 0x03bb
### ↦ is 0x21a6
### ⛥ is 0x26e5
### ψ is 0x03c8
### χ is 0x03c7

# Copyright © 2021, Ioannis Konstantoulas. All rights reserved.
