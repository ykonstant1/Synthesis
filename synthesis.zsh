#!/bin/zsh

# Preamble

setopt pipefail
setopt rc_quotes
setopt re_match_pcre

zmodload zsh/mathfunc
zmodload zsh/pcre
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

## To avoid overuse of quotes
export nl=$'\n'
export cr=$'\r'
export wh=$' '
export tb=$'\t'
export null=$'\0'
export input_delimiter=$'\n'
export output_delimiter=$'\n'
export word_delimiter=$wh

## For conciseness in user-created functions
alias lex='local x; x=("${(@)__buf__}")'
alias rex='__buf__=("${(@)x}")'

alias ⛥='•|➢ '
alias ◎='out'
alias ➢='synth'
alias reduce='foldl'
alias tabulate='segment'
alias •='dot'
alias λ='lambda'

alias swap='map Swap'
alias keep='map Keep'
alias excise='map Excise'
alias permute='map Permute'
alias freplace='map Freplace'
alias regex_freplace='map Regex_freplace'
alias over='map Over'
alias fmix='map Fmix'

# Synthesis main functions

## Building blocks for user-defined functions

input() {
	eval "$1"'=("${(@)__buf__}")'
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
		print -n "\tEval string:"
		print -r -- "'$__exec_string__'"
	}
	[[ $__literal__ ]] && {
		print -n "\tLiteral contents at token:"
		print -r -- "'$__literal__'"
	}
	[[ $__question__ ]] && {
		print -n "\tQuestion contents at token:"
		print -r -- "'$__question__'"
	}
}

passthrough() {
	local foo
	input foo
	ret foo
}

## Buffer Input / Output

publish() {
	eval "${1:-__BUF__}"'=("${(@)__buf__}")'
	eval 'export '"$1"
}

out() {
		print -rn -- "${(pj:$output_delimiter:)__buf__[@]}""$output_delimiter"
}

save() {
	[[ -f $1 ]] && 
		{ __debug "File already exists."; return 1 } ||
		touch "$1" || 
		{ __debug "Cannot create save file."; return 1 }
	
	local entry
	for entry in "${(@)__buf__}"; do
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
		__buf__+=( "$(print -rn -- "$entry" | base64 -d)" )
	done < "$1" 
}

## Buffer display functions

show() {
	local l=1; local r=-1
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
		local i
		local chunk
		for ((i=1; i <= ${#seg}; i++)); do
			chunk=( "${(@ps:$word_delimiter:)seg[i]}" )
			cols+=( "${(pj:$word_delimiter:)chunk[l,r]}" )
		done
		ref="cols"
	}

	printf -- "%s\n" "${(@P)ref}"
}

inspect() {
	local l=1; local r=-1
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
		local i
		local chunk
		for ((i=1; i <= ${#seg}; i++)); do
			chunk=(${(ps:$word_delimiter:)seg[i]})
			cols+=( "${(pj:$word_delimiter:)chunk[l,r]}" )
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

## Buffer counting functions

count() {
	__buf__=${#__buf__}
}

fcount() { #Assumes rectangular table; record interpretation
	__buf__="${#${(@ps:$word_delimiter:)__buf__[1]}}"
}

partcount() { #Does not see nested partitions
	__buf__="${#${(@M)__buf__:#$1:*}}"
}

## Buffer populating functions

get_files() {
	setopt extended_glob
	local quals=''
	local dir=${(e)__literal__:-'./*'}
	local params="$*"

	fformats	#See Component functions
	dir+=$quals
	__buf__=($~dir)
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
	[[ -n $__literal__ ]] &&
		__buf__=( "${(e)__literal__}" ) ||
		__buf__=( "$@" )
}

## Direct buffer modification

unique() { __buf__=("${(@u)__buf__}") }

duplicate() {	__buf__+=( "${(@)__buf__}" ) }

concat() { 
	local sep=${(e)__literal__-$1}
	__buf__=("$__buf__[1]$sep$__buf__[2]"); 
}

encode_all() {
	local i
	for ((i=1; i <= ${#__buf__}; i++)); do
		__buf__[i]=$( print -rn -- "$__buf__[i]" | base64 | tr --delete '\n' )
	done
}

decode_all() {
	local i
	for ((i=1; i <= ${#__buf__}; i++)); do
		__buf__[i]=$( print -rn -- "$__buf__[i]" | base64 -d )
	done
}

transpose() {
	local rows=${#__buf__}
	local entry
	local row_size="${(@ws:$word_delimiter:)#__buf__[1]}"
	local spl
	local col_arr=()

	for entry in "${(@)__buf__}"; do
		[[ "${(@ws:$word_delimiter:)#entry}" -eq $row_size ]] ||
			{ __debug "Not a rectangular table."; return 1 }
		spl=("${(@ps:$word_delimiter:)entry}")
		col_arr+=( "${(@)spl}" )
	done

	__buf__=( "${(@)col_arr}" )
	segment $rows $word_delimiter
}

zip() {
	[[ $(( ${#__buf__} % 2 )) -ne 0 ]] && 
		{ __debug "Cannot zip odd-sized buffer."; return 1 }

	local half=$(( ${#__buf__} / 2 ))
	local fi=("${(@)__buf__[1,half]}")
	local se=("${(@)__buf__[half+1,-1]}")
	__buf__=("${(@)fi:^se}")
}

unzip() {
	[[ $(( ${#__buf__} % 2 )) -ne 0 ]] && 
		{ __debug "Cannot unzip odd-sized buffer."; return 1 }

	local evar=()
	local odar=()
	local i
	local sz=${#__buf__}

	for ((i=1; i <= $sz; i+=2)); do 
		odar=( "${(@)odar}" "$__buf__[$i]" )
	done
	for ((i=2; i <= $sz; i+=2)); do 
		evar=( "${(@)evar}" "$__buf__[$i]" )
	done

	__buf__=( "${(@)odar}" "${(@)evar}" )
}

extract() {
	local non=''

	[[ $@ =~ 'or (.+)$' ]] && non=$match[1] 

	[[ -n $__literal__ ]] && {
		[[ $__literal__ =~ '➭' ]] && {
			local spl=( "${(@ps.➭:.)__literal__}" )
			[[ $__buf__ =~ ${~spl[1]} ]] && {
				__buf__=( "${(@e)spl[2]}" ) 
			} || {
				__buf__=( "$non" )
			}	
		} || {
			[[ $__buf__ =~ ${~__literal__} ]] && {
				__buf__=("${(@pj:$word_delimiter:)MATCH}") 
			} || {
				__buf__=( "$non" )
			}
		}
	}
}

expand() {
	[[ -n $__literal__ ]] && {
		local sep="${(e)__literal__}";
		__buf__=( ${(@ps:$sep:)__buf__} );
		return 0
	}

	[[ $# -ne 0 ]] 	&& 
		__buf__=( ${(@ps:$1:)__buf__} ) ||
		__buf__=( ${(@ps:$word_delimiter:)__buf__} )
}

contract() {
	[[ -n $__literal__ ]] && {
		local sep="${(e)__literal__}"
		__buf__=( "${(pj:$sep:)__buf__[@]}" )
		return 0
	}

	[[ $# -ne 0 ]]	&& 
		__buf__=("${(pj:$1:)__buf__[@]}") ||
		__buf__=("${(pj:$word_delimiter:)__buf__[@]}")
}

dissolve() {
	local dist=()
	local i
	local st="${(@j::)__buf__}"
	for ((i=1; i <= ${#st}; i++)); do
		dist+=( "$st[i]" )
	done
	__buf__=( "${(@)dist}" )
}

prefix() {
	[[ -n $__literal__ ]] && {
		local sp="${(e)__literal__}"
		__buf__=("$sp"${^__buf__}) 
		return 0
	}
	__buf__=("$*"${^__buf__})
}

suffix() {
	[[ -n $__literal__ ]] && { 
		local sp="${(e)__literal__}"
		__buf__=(${^__buf__}"$sp") 
		return 0
	}
	__buf__=(${^__buf__}"$*")
}

group() {
	local groups=(${=@})
	local tmp=()
	local __buf_return__=()
	local i
	local l; local r
	for ((i=1; i <= ${#groups}; i++)); do
		l=${groups[$i]%%,*}
		r=${groups[$i]##*,}
		tmp=( "${(@)__buf__[$l,$r]}" )
		tmp=( "$i:"${^tmp} )
		__buf_return__+=( "${(@)tmp}" )
	done
	__buf__=( "${(@)__buf_return__}" )
}

segment() {
	local columns
	local __buf_size__=${#__buf__}

	local del

	if [[ $1 =~ '\d+' ]]; then 
		columns=$1
		if [[ -n $__literal__ ]]; then
			del=${(e)__literal__}
		elif [[ $2 ]]; then
			del=$2
		else
			del=$word_delimiter
		fi
	else
		columns=$( best_fit $__buf_size__ ) # See component functions
		if [[ -n $__literal__ ]]; then
			del=${(e)__literal__}
		elif [[ $2 ]]; then
			del=$2
		else
			del=$word_delimiter
		fi
	fi

	local i
	local j
	local __buf_return__=()
	local row

	[[ $(( $__buf_size__ % $columns )) -ne 0 ]] &&
		{ __debug "Buffer indivisible by column number."; return 1 }
	local rows=$(( __buf_size__ / columns ))

	for ((j=1; j <= $rows; j++)); do
		row="$__buf__[j]"
		for ((i=1; i < $columns; i++)); do
			index=$((i*rows + j))
			row="$row""$del""$__buf__[$index]"
		done
		__buf_return__+=("$row")
	done
	__buf__=( "${(@)__buf_return__}" )
}

unify() { #To aggregate a partitioned buffer
	__buf__=( "${(@)__buf__/*:/}" )
}

partialsum() {
	local __buf_size__=${#__buf__}
	[[ $__buf_size__ -lt 2 ]] && return 0;
	
	local sep

	if [[ $# -ne 0 ]]; then
		sep=${(e)__literal__-$1}
	else
		sep="$word_delimiter"
	fi

	local __buf_return__=()

	local entry="$__buf__[1]"
	__buf_return__+=( "$entry" )
	local i

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
	[[ -n $__literal__ ]] &&
		__buf__=( $__literal__ "${(@)__buf__}" ) ||
			__buf__=( $@ "${(@)__buf__}" )
}

prepend() {
	[[ -n $__literal__ ]] &&
		__buf__=( "${(e)__literal__}" "${(@)__buf__}" ) ||
		__buf__=( $@ "${(@)__buf__}" )
}

append_raw() {
	[[ -n $__literal__ ]] &&
		__buf__=( "${(@)__buf__}" $__literal__ ) ||
		__buf__=( "${(@)__buf__}" $@ )
}

append() {
	[[ -n $__literal__ ]] &&
		__buf__=( "${(@)__buf__}" "${(e)__literal__}" ) ||
		__buf__=( "${(@)__buf__}" $@ )
}

lshift() {
	local count
	local bc=${#__buf__}

	[[ $# -eq 0 ]] && count=1 || count=$1
	[[ $bc -le $count ]] && {__buf__=(); return 0}
	[[ $count -lt 0 ]] && count=$((bc + count))
	(( ++count ))
	__buf__=( "${(@)__buf__[count, -1]}" )
}

rshift() {
	local count
	local bc=${#__buf__}

	[[ $# -eq 0 ]] && count=1 || count=$1
	[[ $bc -le $count ]] && {__buf__=(); return 0}
	[[ $count -lt 0 ]] && count=$(( -count)) || count=$(( bc - count ))

	__buf__=( "${(@)__buf__[1, count]}" )
}

rotate() {
	local count
	local en
	[[ $# -eq 0 ]] && count=1 || count=$1
	if [[ $count -gt 0 ]]; then
		count=$[count % ${#__buf__}]
		__buf__=( "${(@)__buf__[count+1,-1]}" "${(@)__buf__[1,count]}" )
	elif [[ $count -lt 0 ]]; then
		count=$[ ${#__buf__} - ((-count) % ${#__buf__}) ]
		__buf__=( "${(@)__buf__[count+1,-1]}" "${(@)__buf__[1,count]}" )
	fi
}

mix() {
	local entries=()
	while [[ $1 =~ '(-?\d):(\w+)' ]] do
		entries+=( $1 )
		eval "local $match[2]=$__buf__[$match[1]]"
		shift
	done

	local outent=$match[1]
	local outvar=$match[2]

	[[ -n $__literal__ ]] &&
		local __exec_string__="$__literal__" ||
		local __exec_string__="$@"

	eval "$__exec_string__" || 
		{__debug "Error in mix eval."; return 1}

	while [[ $entries ]]; do
		outent=( "${(@s.:.)entries[1]}" )
		__buf__[$outent[1]]=${(P)outent[2]}
		shift entries
	done

}

## Search and replace functions on buffer

regex_replace(){
	local strings=()
	local cop
	if [[ -n $__literal__ ]]; then
			strings=(${(ps.$__rep__.)__literal__})
			regexp-replace __buf__ "$strings[1]" "$strings[2]"
			return 0
	else
			regexp-replace __buf__ "$1" "$2"
			return 0
	fi
}

replace(){
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
	local fields=()
	local retstr=()
	[[ $1 == 'all' ]] && 
		{ fields=($( seq "${#${(@ps:$word_delimiter:)__buf__}}" )); shift }
	while [[ ! $(declare -f $1) && $1 =~ '\d+' ]]; do
		fields+=( $1 )
		shift
	done

	local i
	local __exec_string__="$@"
	local spl=( "${(@ps:$word_delimiter:)__buf__}" )

	for i in $fields; do
		__buf__=( "$spl[$i]" )
		eval "$__exec_string__" || 
			{__debug  "Error during field eval."; return 1 }
		spl[i]="$__buf__"
	done

	__buf__=( "${(pj:$word_delimiter:)spl[@]}" )
}

Swap() { #record interpretation
	local spl=( "${(@ps:$word_delimiter:)__buf__}" )
	local tmp=$spl[$1]
	local smp=$spl[$2]
	spl[$1]=$smp
	spl[$2]=$tmp
	__buf__=( "${(pj:$word_delimiter:)spl}" )
}

Keep() {	#record interpretation
	local list=($@)
	local count=$#
	[[ $count -eq 0 ]] && {__buf__=(); return 0}

	local kept=()
	local spl=( "${(@ps:$word_delimiter:)__buf__}" )
	local i

	for i in {1..${#list}}; do 
		[[ $list[$i] -lt 0 ]] && list[$i]=$(( ${#spl} + $list[$i] + 1 ))
	done

	for ((i=1; i <= $count; i++)); do
		kept+=( "$spl[$list[i]]" )
	done

	local retstr="${(pj:$word_delimiter:)kept}"
	__buf__=( "$retstr" )
}

Excise() {	#record interpretation
	local ex=($@)
	[[ ${#ex} -eq 0 ]] && return 0
	
	local kept=()
	local spl=( "${(@ps:$word_delimiter:)__buf__}" )

	local count=${#spl}
	local i

	for i in {1..${#ex}}; do 
		[[ $ex[$i] -lt 0 ]] && ex[$i]=$(( $count + $ex[$i] + 1 ))
	done

	local list=({1..$count})
	list=(${list:|ex})

	for i in $list; do
		kept+=( "$spl[$i]" )
	done

	local retstr="${(@pj:$word_delimiter:)kept}"
	__buf__=( "$retstr" )
}

Permute() {	#record interpretation
	local ord=$#
	local perm=($@)
	local spl=( "${(@ps:$word_delimiter:)__buf__}" )

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

	local retstr="${(@pj:$word_delimiter:)temp_arr}"
	__buf__=( "$retstr" )
}

Freplace() { #record interpretation
	local strings=()
	local cop
	local spl=( "${(@ps:$word_delimiter:)__buf__}" )
	local i=$1
	if [[ -n $__literal__ ]]; then
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
	local retstr="${(pj:$word_delimiter:)spl}"
	__buf__=( "$retstr" )
}

Regex_freplace() { #record interpretation
	local strings=()
	local cop
	local spl=( "${(@ps:$word_delimiter:)__buf__}" )
	local i=$1
	shift
	local tmpstr=$spl[i]
	if [[ -n $__literal__ ]]; then
		cop="$__literal__"
		strings=(${(ps.$__rep__.)cop})
		regexp-replace tmpstr $strings[1] $strings[2]
	else
		regexp-replace tmpstr $1 $2
	fi
	spl[i]="$tmpstr"
	local retstr="${(pj:$word_delimiter:)spl}"
	__buf__=( "$retstr" )
}

Fmix() {
	local fields=()
	local spl=( "${(@ps:$word_delimiter:)__buf__}" )
	while [[ $1 =~ '(-?\d):(\w+)' ]] do
		fields+=( $1 )
		eval "local $match[2]=$spl[$match[1]]"
		shift
	done

	local outfield=$match[1]
	local outvar=$match[2]

	[[ -n $__literal__ ]] &&
		local __exec_string__="$__literal__" ||
		local __exec_string__="$@"

	eval "$__exec_string__" || 
		{__debug "Error in field mix eval."; return 1}

	while [[ $fields ]]; do
		outrec=( "${(@s.:.)fields[1]}" )
		spl[$outrec[1]]=${(P)outrec[2]}
		shift fields
	done

	local retstr="${(pj:$word_delimiter:)spl}"
	__buf__=( "$retstr" )
}

## Direct execution functions and lambdas

run() {
	[[ -n $__literal__ ]] ||
		{ __debug "Literal run string not set."; return 1 }
	local __exec_string__="${__literal__//$1/__buf__[1]}"
	eval "$__exec_string__"
}

lambda() { 
	local blocks=("${(ps:$__lsep__:)*}")
	local args=(${=blocks[1]})
	local arg
	local __bc__=${#__buf__}

	[[ ${#__buf__} -lt ${#args} ]] && 
		{__debug "Too small buffer size for lambda: $__bc__ vs ${#args}"; return 1}

	for arg in $args; do
		eval 'local '"$arg"'="$__buf__[1]"; shift __buf__' ||
			{__debug "Error in lambda assignment eval."; return 1}
	done

	if [[ -n $__literal__ ]]; then
	__buf__=( "$(eval "$__literal__")" ) ||
		{__debug "Error in lambda execution eval."; return 1}
	elif [[ -n $__question__ ]]; then
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
	local ind=$1
	local typ='o'
	local i
	local insort=()
	local sortout=()
	[[ $@ =~ 'num' ]] && typ+='n'
	[[ $@ =~ 'ins' ]] && typ+='i'
	[[ $@ =~ 'des' ]] && typ=${typ/o/O}
	swap 1 $ind
	for ((i=1; i <= ${#__buf__}; i++)); do
		if [[ $word_delimiter == ':' ]]; then
			eval 'insort+=(${__buf__[i][(ws.'$word_delimiter'.)1]})'
		else
			eval 'insort+=(${__buf__[i][(ws:'$word_delimiter':)1]})'
		fi
	done
	eval 'insort=( "${(@'$typ')insort}" )'
	for ((i=1; i <= ${#__buf__}; i++)); do
		local inner=${__buf__[(i)$insort[i]$word_delimiter*]}
		sortout+=( "${__buf__[inner]}" )
		__buf__[inner]=''
	done
	__buf__=( "${(@)sortout}" )
	swap 1 $ind
}

msort() { #use only as last resort; very slow
	local size=${#__buf__}
	[[ size -eq 1 ]] && return 0

	local __exec_str__
	[[ $@ ]] && __exec_str__="$@" || __exec_str__="scomp"
		
	[[ $size -eq 2 ]] && {
		uns=( "${(@)__buf__}" )
		eval "$__exec_str__" \
			|| {__debug "Error during sort eval."; return 1}
		[[ $__buf__ = "true" ]] \
			&& __buf__=( "${(@)uns}" ) \
			|| __buf__=( "$uns[2]" "$uns[1]" )	
		return 0
	}

	[[ $size -le 20 ]] && {
		smallsort
		return 0
	}

	local hpoint=$((size/2))
	
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
		eval "$__exec_str__" \
			|| {__debug "Error during sort eval."; return 1}
		[[ $__buf__ = "true" ]] \
			&& {buck+=( "$left[1]" ); shift left} \
			|| {buck+=( "$right[1]" ); shift right}
	done

	buck+=( "${(@)left}" )
	buck+=( "${(@)right}" )
	__buf__=( "${(@)buck}" )
}

## Main query functions

matching() {
	local val=true #empty match is vacuously true
	if ! [[ -n $__literal__ ]]; then
		local nargs=$#; [[ $nargs -eq 0 ]] && ret val
		local list=($@)
		
		local i
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
		local list=($@)
		local i
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
	local val=true #empty match is vacuously true

	lex
	x=( "${(@ps:$word_delimiter:)x}" )
	local i; local j
	local list=($@)

	if ! [[ -n $__literal__ ]]; then
		local nargs=$#; [[ $nargs -eq 0 ]] && ret val
		[[ $((nargs % 2)) -ne 0 ]] && 
			{__debug "Unpaired arguments in match: $@"; return 1}

		for ((i=1; i < $nargs; i+=2)); do
			j=$((i+1))
			[[ $x[list[$i]] =~ $list[$j] ]] || val=false
		done
	else
		list=(${(e)=__literal__})
		local nargs=${#list}; [[ $nargs -eq 0 ]] && ret val
		[[ $((nargs % 2)) -ne 0 ]] && 
			{__debug "Unpaired arguments in match: $list, $nargs"; return 1}
		for ((i=1; i < $nargs; i+=2)); do
			j=$((i+1))
			[[ $x[list[$i]] =~ $list[$j] ]] || val=false
		done
	fi
	ret val
}

fomitting() { 
		#this is the tabular version of omits; record interpretation
	local val=false 
		#empty omission is vacuously false

	lex
	x=( "${(@ps:$word_delimiter:)x}" )
	local i; local j
	local list=($@)

	if ! [[ -n $__literal__ ]]; then
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

## Main arithmetic functions

add() {
	__buf__=$(( $__buf__[1] + $__buf__[2] ))
}

sub() {
	__buf__=$(( $__buf__[1] - $__buf__[2] ))
}

mul() {
	__buf__=$(( $__buf__[1] * $__buf__[2] ))
}

idiv() {
	__buf__=$(( $__buf__[1] / $__buf__[2] ))
}

rem() {
	__buf__=$(( $__buf__[1] % $__buf__[2] ))
}

dist() {
	[[ $__buf__[1] -le $__buf__[2] ]] &&
		__buf__=$(( $__buf__[2] - $__buf__[1] )) ||
		__buf__=$(( $__buf__[1] - $__buf__[2] ))
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
	__buf__=$(( __buf__ % $1 ))
}

inc() {__buf__=($((__buf__+1)))}

square() {__buf__=($((__buf__*__buf__)))}

invert() {__buf__=($((1.0/__buf__)))}

trans() {__buf__=($(($1+__buf__)))}

scale() {__buf__=($(($1*__buf__)))}

sroot() {__buf__=($(( sqrt(__buf__) )))}

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
		tmp=$(( __buf__[i] - c ))
		part=$(( sm + tmp ))
		c=$(( part - sm ))
		c=$(( c - tmp ))
		sm=$part
	done
	__buf__=($sm)
}

prod(){
	foldl mul
}

## Main higher order functions

map() {
	local __buf_size__=${#__buf__}
	local __exec_string__="$@"
	local __buf_copy__=("${(@)__buf__}")

	if [[ $# -eq 2 &&
		! $(declare -f $1) &&
		(-n $__literal__) ]]; then
			__exec_string__=${__literal__//$1/__buf__[1]}
	fi

	local entry
	local __buf_return__=()

	for entry in "${(@)__buf_copy__}"; do
		__buf__=( "$entry" )
		eval "$__exec_string__" || {__debug "Error in map eval."; return 1}
		__buf_return__+=( "$__buf__" )
	done
	__buf__=( "${(@)__buf_return__}" )
}

filter() {
	local __buf_size__=${#__buf__}
	local res="true"
	[[ $1 = 'out' ]] && { res="false"; shift }
	local __exec_string__="$@"
	local __buf_copy__=( "${(@)__buf__}" )
	local entry
	local __buf_return__=()

	if [[ $# -eq 2 &&
		! $(declare -f $1) &&
		(-n $__question__) ]]; then

		__question__=${__question__//$1/__buf__[1]}

		for entry in "${(@)__buf_copy__}"; do
			__buf__=( "$entry" )
			eval '__buf__=$( [[ '"$__question__"' ]] && print true || print false )'
			[[ $__buf__ == $res ]] && __buf_return__+=( "$entry" )
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
	[[ $1 =~ '^(\d)+$' ]] && { i=$1; shift } || i=1
	local __exec_string__="$@"
	local __buf_return__=()

	if [[ $# -eq 2 &&
		! $(declare -f $1) &&
		(-n $__literal__) ]]; then
			__exec_string__=${__literal__//$1/__buf__[1]}
	fi
	__buf_return__=( "${(@)__buf__}" )
	while ((i--)); do
			eval "$__exec_string__" || {__debug "Error in induction eval."; return 1}
			__buf_return__+=( "${(@)__buf__}" )
	done
	__buf__=( "${(@)__buf_return__}" )
}

fmap() {
	local __buf_copy__=( "${(@)__buf__}" )
	local fields
	while [[ $1 =~ '^\d+$' ]]; do
		fields+=( $1 )
		shift
	done
	local i
	local __exec_string__="$@"
	
	if [[ $# -eq 2 &&
		! $(declare -f $1) &&
		(-n $__literal__) ]]; then
			__exec_string__=${__literal__//$1/__buf__[1]}
	fi

	local entry
	local spl
	local __buf_return__=()

	for entry in "${(@)__buf_copy__}"; do
		spl=( "${(@ps:$word_delimiter:)entry}" )
			for i in $fields; do
				__buf__=( "$spl[$i]" )
				eval "$__exec_string__" || { __debug  "Error in field map eval."; return 1 }
				spl[i]="$__buf__"
			done
			__buf_return__+=("${(pj:$word_delimiter:)spl[@]}")
	done
	__buf__=( "${(@)__buf_return__}" )
}

ffilter() {
	local __buf_size__=${#__buf__}
	local __buf_copy__=( "${(@)__buf__}" )

	local fields
	while [[ $1 =~ '\d+' ]]; do
		fields+=( $1 )
		shift
	done
	local i
	local __exec_string__="$@"
	local spl=()
	local retstr=()

	local entry
	local __buf_return__=()

	if [[ $# -eq 2 && \
		! $(declare -f $1) && \
		(-n $__question__) ]]; then

		__question__=${__question__//$1/__buf__[1]}
		for entry in "${(@)__buf_copy__}"; do
			local retstr=()
			local accept=1
			spl=( "${(@ps:$word_delimiter:)entry}" )
			for ((i=1; i <= ${#spl}; i++)); do
				if [[ $fields[(r)$i] ]]; then 
					__buf__=( "$spl[i]" )
					eval '__buf__=$( [[ '"$__question__"' ]] && print true || print false )'
					[[ $__buf__ == "true" ]] && retstr+=( "$spl[i]" ) || accept=0
				else
					retstr+=( "$spl[i]" )
				fi
			done
			[[ $accept = 1 ]] &&
				__buf_return__+=( "${(@pj:$word_delimiter:)retstr[@]}" )
		done
		__buf__=( "${(@)__buf_return__}" )

	else
		for entry in "${(@)__buf_copy__}"; do
			local retstr=()
			local accept=1
			spl=( "${(@ps:$word_delimiter:)entry}" )
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
				__buf_return__+=( "${(@pj:$word_delimiter:)retstr[@]}" )
		done
		__buf__=( "${(@)__buf_return__}" )
	fi
}

partition() {
	local __buf_size__=${#__buf__}
	local __exec_string__="$@"
	local __buf_copy__=( "${(@)__buf__}" )

	if [[ $# -eq 2 &&
		! $(declare -f $1) &&
		(-n $__literal__) ]]; then
			__exec_string__=${__literal__//$1/__buf__[1]}
	fi

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

partmap() {
	local parts=( ${(ps.:.)@[1]} )
	shift
	local __exec_string__="$@"

	[[ $# -eq 2 &&
		! $(declare -f $1) &&
		(-n $__literal__) ]] &&
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
	while ((iters--)); do
		eval "$__exec_string__" || 
			{ __debug "Error in power eval."; return 1 }
	done
}

develop() { #Takes f : X x X -> Y and returns matrix of outputs
	local __buf_size__=${#__buf__}
	local __exec_string__="$@"
	local __buf_copy__=( "${(@)__buf__}" )

	if [[ $# -eq 2 &&
		! $(declare -f $1) &&
		(-n $__literal__) ]]; then
			__exec_string__=${__literal__//$1/__buf__}
	fi

	local xentry yentry
	local __buf_return__=()
	local entry_return
	for xentry in "${(@)__buf_copy__}"; do
		entry_return=''
		for yentry in "${(@)__buf_copy__}"; do
			__buf__=( "$xentry" "$yentry" )
			eval "$__exec_string__" || {__debug "Error in develop eval."; return 1}
			entry_return+="$__buf__[@]""$word_delimiter"
		done
		entry_return="${entry_return%%$word_delimiter}"
		__buf_return__+=( "$entry_return" )
	done
	__buf__=( "${(@)__buf_return__}" )
}

unfold() { # takes f : X -> X x X and induces, interleaving in/out
	local i
	[[ $1 =~ '^(\d)+$' ]] && { i=$1; shift } || i=1
	local __exec_string__="$@"
	local __buf_return__=()

	if [[ $# -eq 2 &&
		! $(declare -f $1) &&
		(-n $__literal__) ]]; then
			__exec_string__=${__literal__//$1/__buf__[1]}
	fi

	__buf_return__=( "${(@)__buf__}" )
	while ((i--)); do
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

	if [[ $# -eq 2 &&
		! $(declare -f $1) &&
		(-n $__literal__) ]]; then
			__exec_string__=${__literal__//$1/__buf__}
	fi
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
				__buf_return__+=( "$__buf_copy__[$i]" )
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
		[[ $__buf__[i] =~ "^(\w+)\:" ]] && \
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
	[[ -n $__literal__ ]] && ref="__literal__"
	local buf=( "${(@)__buf__}" )
	[[ -f ${(P)ref} ]] && {
		load ${(P)ref}
			__buf__=( "${(@)__buf__}" "${(@)buf}" )
	} || {
		${(ezP)ref} 2>/dev/null || __buf__="${(@P)ref}"
		__buf__=( "${(@)__buf__}" "${(@)buf}" )
	}
}

Append() {
	local ref="@"
	[[ -n $__literal__ ]] && ref="__literal__"
	local buf=( "${(@)__buf__}" )
	[[ -f ${(P)ref} ]] && {
		load ${(P)ref}
		__buf__=( "${(@)buf}" "${(@)__buf__}" )
	} || {
		${(ezP)ref} 2>/dev/null || __buf__=${(P)ref}
		__buf__=( "${(@)buf}" "${(@)__buf__}" )
	}
}

## Main loop

synth() {
	local __parameters__="${@//$'\\\n'/ }"
	local __comands__=("${(@ps/$__pipe__/)__parameters__}")				
	local __comand_count__=${#__comands__}
	local __commands__=()
	local i
	local rep
	local strr
	local strm

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

	while IFS= read -r -d $input_delimiter bin; do
		__buf__+=($bin)
	done

	local __buf_size__=${#__buf__}
	local __exec_string__
	local __literal__
	local __question__
	local errst=0
	
	for ((i=1; i <= __command_count__; i++)); do

		unset __literal__
		unset __question__

		__exec_string__="${__commands__[i]#"${__commands__[i]%%[![:space:]]*}"}"
		__exec_string__="${__exec_string__%"${__exec_string__##*[![:space:]]}"}" 

		[[ $__exec_string__ =~ $__llit__ ]] && {
			__literal__="${__exec_string__##*$__llit__}";
			__literal__="${__literal__%%$__rlit__*}";
 			__exec_string__="${__exec_string__/$__llit__*$__rlit__/__token__}" 
		}

		[[ $__exec_string__ =~ $__lque__ ]] && {
			__question__="${__exec_string__##*$__lque__}"; \
			__question__="${__question__%%$__rque__*}"; \
 			__exec_string__="${__exec_string__/$__lque__*$__rque__/_question_}" 
		}

		eval "$__exec_string__" || errst=$?

		[[ $errst == 1 ]] &&
			{__debug "Eval fail in main loop at command $i."; return 1}
		[[ $errst == 2 ]] &&
			{__debug "Inspection terminated pipeline after command $((i-1))."; return 0}
	done
}

## Component functions

dot() { printf $input_delimiter } # For piping empty state to synth

best_fit() { # Component in segment
	local X=$1
	local S=sqrt($X)
	local low_divisors=( 1 )
	for ((i=2; i <= $S; i++)); do
		[[ $((X % i)) -eq 0 ]] && \
			 low_divisors+=( $i );
	done
	print $(( X / low_divisors[-1] ))
}

fformats(){ #Component in get_files()
	typeset -A fl
	fl[N]='^'
	fl[L]='-'
	fl[LN]='-^'
	fl[NL]='^-'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?dir' ]] && quals+='(#q'${fl[$match[2]]}'/)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?full(?:dir)?' ]] && quals+='(#q'${fl[$match[2]]}'F)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?reg(?:ular)?' ]] && quals+='(#q'${fl[$match[2]]}'.)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?so(?:cket)?' ]] && quals+='(#q'${fl[$match[2]]}'=)'
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
	[[ $params =~ '(^|\s)(N|L|NL|LN)?onlinks' ]] && quals+='(#q'${fl[$match[2]]}'-)'
	[[ $params =~ '(^|\s)(N|L|NL|LN)?dots' ]] && quals+='(#q'${fl[$match[2]]}'D)'
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
	[[ $params =~ '(^|\s)(\d+),(\d*)' ]] && quals+='(#q['$match[1]','${match[2]:-"-1"}'])'
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
		local i=$((${#sor}+1))
		while ((i--)); do
			if [[ $i -eq 0 ]]; then
				sor=($iter[1] $sor)
				break
			fi
			__buf__=( "$sor[i]" "$iter[1]" )
			eval "$__exec_str__" \
				|| {__debug "Error during sort eval."; return 1}
			if [[ $__buf__ = "true" ]]; then
				sor=( "${(@)sor[1,i]}" "$iter[1]" "${(@)sor[i+1,-1]}" )
				break
			fi
		done
		shift iter
	done
	__buf__=( "${(@)sor}" )
}

## Emit function; try not to use this

emit() {
	local i=$1
	local entry
	[[ $i -lt 0 ]] && i=$(( ${#__buf__} + $i + 1 ))
	entry="$__buf__[$i]"
	local j=0
	shift
	[[ ! $(declare -f $1) ]] && {
		j=$1
		shift
		entry=( "${(@ps:$word_delimiter:)entry}" )
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
bindkey -s "\`\\" " |➢ " 
bindkey -s "\`o" "◎ " 
bindkey -s "\`x" "•\|➢ "
bindkey -s "\`dot" •
bindkey -s "\`l" "λ "
bindkey -s "\`m" " ↦ "
bindkey -s "\`1" "'«»'ODOD
bindkey -s "\`2" "'⟦⟧'ODOD
bindkey -s "\`q" "⛥ "
bindkey -s "\`r" "➭:"
bindkey -s "\`t" "ψ"
bindkey -s "\`x" "χ"
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
