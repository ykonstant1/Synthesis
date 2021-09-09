# User Manual for the Synthesis Script

---

##### Ioannis Konstantoulas
##### 5th of June, 2021

# Table of Contents

1. Introduction
	1. Overview
	2. Installation and Usage
	3. Prerequisites
	4. Credits
2. Working with synthesis
	1. Basic structure
	2. Synthesis functions
	3. Worked examples
	4. Performance and stability
	5. A note on Unicode
3. Copyright and licence

# 1. Introduction

## 1.1. Overview

Synthesis is a collection of zsh functions and primitives for
enabling a map/filter/fold coding style.  It is meant to be used
alongside pure zsh code, as "inner pipelines" performing buffered
filtering and transformation tasks in a more composable and linear
style than raw shell code.

The workflow starts with the ```synth``` command taking arbitrary
data from standard input or generating its own data, which it then
buffers and passes through a sequence of special functions.
Ultimately, the processed result is output to standard output or
given as input to some command.  The basic pattern is illustrated
by the following code:

```
seq 10	|	➢  prefix data ⇝ suffix .dat \
			⇝ filter v '⟦ ! -f $v ⟧' \
			⇝ map run v '« touch $v »'
```

This code, the details of which will be explained later on, creates
ten files `data1.dat`, `data2.dat`, ...,`data10.dat` using touch,
without touching already existing files.

## 1.2. Installation and usage

To activate synthesis, source the file `synthesis.zsh` in a zsh
terminal.

The basic pipeline is

```
...commands | synth function_1 ⇝ function_2 ⇝ ... ⇝ out | commands...
```

The zsh function `synth` is the main executable, and everything up
to and including `out` is interpreted inside it.  

The pipeline operator `⇝` is invoked via `` `p ``.

In this document and the author's code, `synth` is always aliased
to `➢` and `out` is always aliased to `◎` .  In this form, the pipeline
pattern is 

```
...commands | ➢ function_1 ⇝ function_2 ⇝ ... ⇝ ◎ | commands...
```
  The alias `➢` is invoked via `` `w `` and the alias `◎` via `` `o ``.  

When using `synth` to generate its own data, the invocation pattern
is 

```
⛥ function_1 ⇝ function_2 ⇝ ... ⇝ ◎ | commands...
```

The star `⛥`, invoked via `` `q ``, initializes an empty buffer and calls `synth`.

The functions forming the pipeline are a combination of predefined
higher order functions, user-defined synthesis functions and
anonymous functions/conditionals given by literals in a special
format.

## 1.3. Prerequisites

To make the best use of this script, you should be familiar with
zsh shell scripting at a basic level.  This includes basic shell
syntax, zsh functions, scalars and arrays, the simplest quotation
rules and how to set options and environment variables.

Synthesis uses a hybrid imperative/functional paradigm based on
higher order functions such as map and filter being applied to
user-defined or script-supplied functions, with as little hidden
state as possible.  The script is aimed at users who have some
familiarity with this coding style.

## 1.4. Credits

This script was inspired by Slawomir Sledz's
[bash-fun](https://github.com/ssledz/bash-fun) script which
provides some functional patterns for bash.  That script, in turn,
was inspired by [fun.sh](https://github.com/mikeplus64/fun.sh)
written by Mike Ledger in 2012.  

As an amateur zsh programmer, I asked questions on
[r/zsh](old.reddit.com/r/zsh) and received several helpful answers,
particularly by the user romkatv.

# 2. Working with Synthesis

A note on terminology: by *atomic functions* we mean functions that
do not pass any of their parameters through an `eval`.  In
contrast, *higher order functions* pass some of their parameters
through at least one `eval`.  This is not a hard-and-fast rule, but
meant to convey the intent behind the two kinds of functions.

## 2.1. Basic structure

The synth pipeline begins in one of the following two ways:

```
⛥ function_1 ⇝ function_2 ⇝ ...
```

or

```
...commands | ➢ function_1 ⇝ function_2 ⇝ ...
```

The first invocation is equivalent to an empty stream piped in the
second invocation and is used to signify that data is generated
by the synth script itself.

Synthesis uses a single global array variable denoted `__buf__`,
which every function and operator modifies implicitly.  Each
`function_i` in the pipeline retrieves the contents of `__buf__`
one way or another, and mutates the variable or produces some
side-effect.  Side-effects may include printing buffer contents on
some file descriptor, saving/loading the contents, publishing as an
environment variable, and many more.

By default, `synth` accepts newline-delimited input and creates
buffer entries this way.  This can be modified by altering the
`input_delimiter` environment variable to another string.  This is
especially important when the input is filenames, in which case the
input delimiter should always be set to the zero byte via
`input_delimiter=$null`.

The synth pipeline usually ends with one of the following terminating
commands:

```
... ⇝ out ( or equivalently ... ⇝ ◎ )
... ⇝ show
... ⇝ map run [some command to be performed on each buffer entry ]
```

The first `print`s the buffer contents
for further processing as a string delimited by the environment
variable `output_delimiter`.  Again, when filenames or other binary
data is involved, `output_delimiter` should be set to `null`.  Show
also outputs the data, but can take formatting options and is meant
to display data on the terminal.  "Run" style commands do not
display the data and rather perform an action, usually
invoking some external program on the data.  There are many more
ways to end the pipeline; see the input/output section of Synthesis
Functions for more information.

The individual `function_i` directives form the core of the script.
They follow one of the following types in increasing order of
complexity:

### A. Atomic functions `f()`

Atomic functions, together with lambdas and literals, are the basic
building blocks of higher order constructs.  Most of the
user-defined functions are expected to be of this type, or the type
B defined below.

Atomic functions have the form 

```
f() # with whitespace-separated alphanumeric parameters
{ 
	local x # define a name for the buffer contents
	input x # get the contents of __buf__ by value
	...
	#do things to x
	...
	ret x # write the results of the actions back to __buf__
	# or produce some side-effect
}
```

Here, `f` can be any ASCII alphanumeric string, with parameters
restricted similarly to non-whitespace, ASCII alphanumeric strings
(type B below removes this restriction).  Similarly `x` can stand
for any alphanumeric variable.  Apart from the fact that `x` is an
array variable, there are no a priori constraints to its shape,
type, number of elements, etc.  It is up to the creator of `f` to
decide what `x` is interpreted as, and up to the creator of the
pipeline to ensure that the pipeline furnishes `f` with compatible
contents.

As an example, the following function prefixes each entry of the
array with the string supplied as a parameter:

```
prefix_naive() {
	local x
	input x
	x=("$*"${^x})
	ret x
}
```

As a second example, the following function sums the elements of
the array and returns the result:

```
sum_naive() {
	local x
	input x
	local y=0
	while [[ $x ]]; do
		y=$(( y + x[1] ))
		shift x
	done
	ret y
}
```

In order to reduce boilerplate, synth defines two aliases `lex` and
`rex` standing for `lex='local x; input x'` and `'ret x'`
respectively.  This allows the two functions above two be written
as

```
prefix_naive() { lex; x=("$*"${^x}); rex }
```

and 

```
sum_naive() {
	lex
	local y=0
	while [[ $x ]]; do
		y=$(( y + x[1] ))
		shift x
	done
	ret y
}
```

respectively.

Atomic functions of course do not *need* to retrieve data or return
them, so they can act as sources or sinks for buffer contents.  For
example, `seql_naive` below populates the buffer with a sequence of
consecutive integers beginning at 1:

```
seq_naive() {
	local x=({1..$1})
	ret x
}
```

Let's summarize the above by putting them in a pipeline:

```
⛥ seq_naive 5 ⇝ sum_naive ⇝ prefix 'Result:' ⇝ show
```

The output of this pipeline is `Result:15`.

### B. Atomic functions with complex parameters

The restriction on the parameters of atomic functions to be
alphanumeric is too onerous.  Since `synth` is a zsh function,
however, it is difficult to include shell-interpretable symbols
without the shell interpreting them at various stages of
evaluation: in higher order constructions, an expression can pass
through an arbitrary number of `eval`s.

The solution is to include specially quoted literals as parameters
to atomic and higher order functions.  This leads to the following
pattern:

```
f() [alphanumeric parameters] '« arbirarily complicated parameters »'
{ 
	# The string enclosed in «» is, uninterpreted, in the variable __literal__
}
```
The special quotation marks `'«»'`, invoked with `` `1 ``, tell synth to grab the enclosed
string before doing any `eval`s, put it in `__literal__`, and have
it ready for when it is needed by the function.

As an example, here is a less naive `prefix` function which closely
resembles the code in the synth script:

```
prefix_better() {
	lex
	if [[ -n $__literal__ ]]; then
		local sp="${(e)__literal__}"
		x=("$sp"${^x}) 
	else
		x=("$*"${^x})
	fi
	rex
}
```

Now we can do the following:

```
⛥ seq_naive 3 ⇝ prefix_better '«Number: |-> »' ⇝ show
```

and get the right result:

```
Number: |-> 1
Number: |-> 2
Number: |-> 3 
```

Due to the way this construct is implemented, only one literal can
be designated per item in the pipeline.  Thus, if the user wants to
create a function taking three complicated parameters, they have to
use a single '«»' and split the contents inside in some manner.

The last restriction on the literals is that they cannot accept a
nested synthesis pipeline.  Synthesis splits commands on pipe
arrows before literals are retrieved for each command, so such
arrows inside literals will produce a splitting error at the top
level.

A large number of builtin atomic functions are provided for various
tasks.  A brief list follows; for the full details, see section
2.2.

**Builtin atomic functions**

1. Arithmetic functions `add`, `sub`, `dist`,...
2. String manipulation functions `replace`,
	 `regex_replace`, `extract`,...
3. Buffer populating functions `seql`, `detect`, `enter`,...
4. Buffer modification functions `append/prepend`, `suffix/prefix`,
	 `rotate/lshift/transpose/reverse/zip/unzip...`
5. Sorting functions `qsort/msort`
6. Array/string conversion `expand/contract/concat/`
7. Array counting functions `count/fcount/partcount`
8. Formatting and display functions `show/inspect/encode/decode`
9. Environment interaction `save/load/publish`
10. Boolean query functions
		`matching/fmatching/omitting/scomp/ncomp...`

### C. Lambda functions

In the context of synthesis, lambda functions are somewhat subtle,
since they perform two tasks: they provide anonymous functions to
be passed to higher order functions, and they transform syntactic
zsh expressions to synthesis-type functions.  This allows the user
to inline a simple task without bothering with the `input/ret`
formalism of atomic synthesis functions.  

The template for lambdas is:

```
λ x y z ... ↦ '« syntactic expression »'
```

The collection `x y z ...` defines the variables to be used in the
syntactic expression; they are populated by consecutive entries of
the array: `x=$__buf__[1]`, `y=$__buf__[2]` etc.  The syntactic
expression is any valid zsh code, including any number of
side-effects; its output is captured into `__buf__`.  **Note** that
when invoking lambda, the previous contents of `__buf__` are always
destroyed.

For example, the following pipeline returns `Result:15` as in
the example of subsection A:

```
⛥ seq_naive 5 ⇝ sum_naive ⇝ λ x ↦ '« print "Result:$x" »' ⇝ show
```

A second, less common invocation of lambda, takes the form

```
λ x y z ... ↦ '⟦ query ⟧'
```
where the special brackets are invoked with `` `2 ``. This is a
shorthand for 

```
λ x y z ... ↦ '« [[ query ]] && print 'true' || print 'false' »'
```
and is meant to simplify filter-like higher order constructs.
However, synth provides a better query shorthand for its filters,
so this lambda pattern is not too useful outside of user-defined
higher order constructs.

Preempting some later discussion, here is an example
pipeline outputting the congruence class 1 modulo 5 with some
decorations:

```
⛥ seq_naive 17 ⇝ filter λ x ↦ '⟦ $(( x % 5 )) -eq 1 ⟧' \
⇝  map λ x ↦ '« print "This is in class 1 modulo 5: $x" »'  ⇝ show
```

This produces the output:

```
This is in class 1 modulo 5: 1
This is in class 1 modulo 5: 6
This is in class 1 modulo 5: 11
This is in class 1 modulo 5: 16
```

In general, although lambdas are convenient, I do not encourage
their use. Atomic operations and queries are better handled wrapped in atomic
functions, and `map/filter/reduce/...` have more concise anonymous
patterns for when necessary.  For example, the pipeline above in
actual synthesis code would be written either as:

```
⛥ seql 17 ⇝ filter x '⟦ $(( x % 5 )) -eq 1 ⟧' \
⇝  map x '« x="This is in class 1 modulo 5: $x" »' ⇝ show
```

or as

```
cong() { lex; [[ $((x % 5)) -eq 1 ]] && x='true' || x='false'; rex }

decorate() { lex; x="This is in class 1 modulo 5: $x"; rex }

⛥ seql 17 ⇝ filter cong ⇝ map decorate ⇝ show
```

Of course the second format is better suited for more complex tasks
involving bigger atomic functions.

As a final remark, note that these lambdas are syntactic
constructs, limited to being passed to synth's higher order
functions as a parameter or being an item in the pipeline by
themselves.  They are not true first class objects in any
functional sense of the word.

### D. Higher order constructs

This is the most useful class of functions defined by Synthesis.
These operators take other functions (either user-defined or
predefined in synth), literals and lambdas, and apply them to the
buffer contents.  The general template is:

```
higher_order_function [optional alphanumeric parameters] function

```
where function can be atomic, a lambda, or even another higher
order function as long as it treats the contents of `__buf__`
compatibly with the outer function.

A comprehensive description of these operators with interfaces and
worked examples can be found in subsections 2.2 and 2.3.  The most
common ones include:
 
1. `map f` : applies f to each element of the array
2. `filter f` : keeps elements satisfying the boolean f
3. `foldl f` : folds the array into a scalar by consecutively
		accumulating partials according to the two-variable f
4. `partition f` : partitions the array into classes defined by f
5. `partmap classes f` : applies f to all elements of classes
	 'class1:class2:..' in a partitioned array
6. `partfold classes f` : as foldl, but limited to the designated
	 classes
7. `foldparts f` : folds all classes according to f, resulting in
	 one element for each class
8. `graphmap f` : like map, but provides the pair `(index, value)`
	 from the array to the two-variable function f.
9. `power n f` : compose f with itself n times
10. `induce n f` : starting from the last entry, apply f and append
		the result to the array, and repeat n-1 times.
11. `Prepend/Append f` : in one of its interfaces, prepends/appends
		the result of the array-populating function f to the existing
		array.
12. `unfold n f` : takes the last entry of the array and applies it
		to f which returns a pair of values to the array, and repeats
		n-1 times.

Some of these functions have additional ways to invoke for
convenience, but all accept the basic format listed above.  For
example, `map` has a shortcut allowing quick syntactic
modifications as in the following example:

```
⛥ seql 5 ⇝ map x '«x="Item: $x"»' ⇝ ◎
```

which is shorter than defining a decorating function or involving a
full lambda.  For more information, read subsection 2.2. carefully:
there exist inconsistencies between some of these shortcuts and the
lambda function!

For now, let's restrict ourselves to the simple format allowed by
all higher order functions and give some basic examples of their
use.  One example that uses several of the above functions is a
cute (non-performant!) way to approximate pi.  The exponentially
convergent formula used can be found in the Middle Ages section of
[Approximations of
pi](https://en.wikipedia.org/wiki/Approximations_of_%CF%80).

```
scale_odd() { lex; x=$(( (2*x[1] - 1)*x[2] )); rex }

⛥ enter 1 ⇝ induce 30 scale -3 ⇝ graphmap scale_odd \
	⇝ map invert ⇝ sum ⇝ scale $((sqrt(12))) ⇝ ◎
```

This command does the following:

a) Initializes the buffer with the entry 1;
b) develops 30 powers of -3 via 1 -> (1, -3) -> (1, -3, 9) -> ...;
c) multiplies each entry with the odd number associated with its
index, using the helper function `scale_odd`;
d) transforms each entry to its reciprocal;
e) sums the entries naively;
f) finally multiplies the result by the square root of 12.

The second example, a fizzbuzz, demonstrates partitioning and
departitioning:

```
fizzes=37 # however many iterations we want

⛥ seql $fizzes ⇝ partition mod 15 \
			⇝ partmap 3:6:9:12 enter '«fizz»' \
			⇝ partmap 5:10 enter '«buzz»' \
			⇝ partmap 0 enter '«fizz buzz»' \
			⇝ unify ⇝ ◎ 
```

This command does the following:

a) creates a list of the first `$fizzes` integers;
b) partitions it modulo 15 (mod is a builtin atomic function);
c) replaces multiples of 3 with fizz, multiples of 5 with buzz, and
multiples of 15 with fizz buzz;
d) removes partition information with `unify` and returns the
resulting fizzbuzz.

Many more (and more serious!) examples of these constructs can be
found in their respective descriptions.

### E. Record/field interpretation of data and tables

In general, higher order functions in Synthesis assume no
interpretation of individual entries in the array, and treat them
as opaque blobs to be passed untouched to atomic functions.
However, tabular data and the record/field paradigm underlying, for
instance, tools like awk, are very useful in a shell context.
For this reason, synthesis supplies many atomic functions and
higher order functions that treat individual entries of the array
as records of `$word_delimiter`-separated fields.

In particular, there are builtin functions for:

1. Swapping or permuting fields in rectangular arrays
	 (swap/permute);
2. Applying maps/filters only to one or more columns (fmap,
	 ffilter, fmatching...);
3. Transposing rectangular arrays (transpose);
4. Keeping all but/removing all but designated columns (keep,
	 excise, extract...);
5. Turning one dimensional data to columnar data and vice-versa
	 (segment/tabulate...);
6. Transforming field entries via functions of other field entries

and more.  Note that, since these records are still just abstract
array entries, all the higher order functions from the previous
section apply just as well to the whole string.

The general template for record-interpreted atomic or higher order functions is:

```
higher_order_function [field or fields to affect] function
#or
atomic_function [field or fields to affect] [optional parameters]
[optional word delimiter]
```

Here we will restrict ourselves to an example of these
functions in action and point to section 2.2 for the full details.

Let's suppose we have a tab-separated table of students with
majors and grades:

```
records.txt:

Name	Major	GPA
John Doe	Mathematics	3.0
Jane Doe	Physics	3.9
Jack Doe	Computer Science	4.0
Jill Doe	Physics	4.0
```

and we want to find the most populous major (assuming it is unique
for simplicity) and the average GPA associated to it.  The
following code does the trick:

```
word_delimiter=$tb

local popular=$( < records.txt ➢ lshift ⇝ keep 2 ⇝ suffix :1 \
	⇝ foldparts add ⇝ lshift -1 ⇝ ◎ )

local pop=( ${(s.:.)popular} )

< records.txt ➢ lshift ⇝ filter fmatching 2 $pop[1] ⇝ keep -1 \
	⇝ sum ⇝ scale $((1.0/$pop[2])) ⇝ ◎
```

The crux of the above is isolating the second field (keep 2) to
count occurrences, afterwards filtering the table by the second
field matching the populous major (fmatching 2...), and finally
keeping only the GPA field (keep -1) to perform the averaging.  

## 2.2. Synthesis functions

This list follows the order and structure of the functions in
`synthesis.zsh`.

Each function has an expected input type and guarantees an output
type (or errors out).  This specification is given in the
language of domains and codomains via 

```
f [optional parameters] required parameters : X -> Y
``` 

Primitive types include Int, Str, Float, Bool, Void, Byte (possibly
further specified in some situations) and more.  Void indicates the
lack of input requirement or output guarantee.  Byte indicates
arbitrary binary data (which zsh variables can carry).  Array(x)
denotes an array of one or more of the above.  The Cartesian
product, e.g. Float x Float, is to be interpreted as a 2-element
array of Floats, etc.  Similarly for a power of a type, e.g.
Bool^5.  An asterisk `*` indicates any primitive type.  An array is
not a primitive type.  String is essentially the same as *.  

Our type annotations are not meant to be strict; they exist to
convey intent, but can be reasonably broken in appropriate
contexts.  Synthesis itself does not perform any type checking.

Functions taking parameters are decorated in their definition by
a description of parameters.  For example:
```
show [ formatting options ] : Array(*) -> Void
```

Bracketed decorations indicate optional parameters, while
unbracketed ones required parameters.  Variants are listed
separately for clarity.

## Building blocks for user-defined functions

These functions do not appear in synthesis pipelines; they are used
within user-defined functions to retrieve and set the internal
buffer.

### `input varname`

**Description:** Here, `varname` is any legal name for a zsh variable;
the function copies the contents of the buffer into x, allowing it
to be used in place of the more onerous variable name `__buf__`.
Note, however, that nothing prevents a function from modifying
`__buf__` directly, and this may increase performance in hot paths.

`input varname` should be preceded by a local declaration like
`local varname`;
otherwise, if `varname` is already set, the command will overwrite the
global variable.  

For convenience, an alias is defined as `lex='local x; input x'`.
It can readily be overwritten with the user's favorite generic name
for a variable.

### `ret varname`

**Variant:** `ret literal`

**Description:** `varname` being as before, `ret` assigns the value of
`varname` to the buffer, or if `varname` is not set, `ret`
interprets `varname` as a
literal string and assigns `'varname'` itself to the buffer.

**Examples:** 

1. `add() { local x; input x; local y=$[ x[1] + x[2] ]; ret y }`
is a typical `add : Int x Int -> Int` function 
2. `even() { lex; [[ $(( x % 2)) -eq 0 ]] && ret 'true' || ret 'false' }`
	 is a typical `f : Int -> Bool` function.

## Buffer Input and Output

### `save filename : Array(*) -> Void`

**Description:** Encodes the input as base64 without newlines and
writes the entries in `filename`, one line for each.

### `load filename : Void -> Array(*)`

**Description:** Accepts a file of base64-encoded lines, decodes
them an populates an array, one entry per line in the file.
`

### `publish [varname] : Array(*) -> Void`

**Description:** Creates environment variable `varname` holding the
contents of the array.  If `varname` is not provided, the variable
name defaults to `__BUF__`.

## Buffer display functions

### `show [begin,end] [fbegin,fend] : Array -> Void`

**Description:** Displays the buffer contents, possibly restricted
to the range `[begin,end]` and possibly restricted to fields
`[fbegin,fend]` if the array is in table form.  Irrespective of
`$output_separator`, it prints the entries line-by-line.

**Example:** `show -5,-1` displays the fifth-last to last array
entry; `show 1,3 -2,-1` displays the window of the last two fields
of the first three array entries.

### `inspect [begin,end] [fbegin,fend] : Array -> Void`

**Description:** As `show`, but inspect halts execution of the
pipeline for the user to inspect contents, and either continues or
aborts the program depending on user input: `q` exits, and any
other key continues.

## Buffer counting functions

### `count/fcount/partcount : Array -> Int`

**Description:** These functions count array elements, array
fields, and number of partitions (created by the `partition`
function) respectively.

## Buffer populating functions

###
```
detect ['«glob»'] [inclusion criteria] 
	N[exclusion criteria] [formatting options] 
	: Void -> Array( Byte_not_null )
```
**Description:** Populates the array with filenames satisfying the
criteria set by the parameters.  The glob accepts zsh globbing
syntax.  

Each criterion can be negated by prefixing it with a capital N.
Each criterion can be applied to the *target* of a symbolic link,
rather than the link file, by prefixing the criterion with a
capital L.

The criteria options (grouped by concept) are:

1. read/write/exec/wread/wwrite/wexec/gread/gwrite/gexec : user,
	 world, group permissions respectively
2. dir/fulldir/blsp/chsp/regular/link: directory, non-empty directory, block or
	 character special device, regular file or symbolic link
3. setuid/setgid/sticky : carrying the respective bit
5. ondev [device] / size [criteria] / nlinks [number] / lastacc
	 [criteria] / lastmod [criteria] / lastinode [criteria] :
	 designating device holding the file, size, number of links, last access,
	 modification or inode change; the accepted criteria format is
	 the same as with zsh native globbing options.
6. dots : include dotfiles in the directory scan
7. mine / mygroup / owner [name] / group [name] : restrict to
	 current user/group files, or designated owner or group
8. [d]sort:name/size/links/lastacc/lastmod/lastinode : ascending or
	 descending sort according to the respective key
9. stopat [number] / [m,n] : stop listing at #numberth
	 file, or get the [m,n] range from the list

The formatting options are:

1. abs : return absolute paths
2. path : return full path
3. linkabs : return absolute path of dereferenced link
4. ext : return extensions only
5. root : remove extensions
6. lower : convert to all lowercase
7. upper : convert to all uppercase
8. head [number] : return only the top [number] of nodes in the
	 path; e.g. head 3 on `/usr/bin/zsh` returns `/usr/bin`
9. tail [number] : same as above, get the bottom [number] of nodes;
	 e.g. tail 2 on `/usr/bin/zsh` gives `bin/zsh`
10. quoted : fully quote the strings according to zsh quoting
		patterns. 

**Example:**
```
⛥ detect dots regular mygroup read sort size Nmine path ⇝ ◎
```
returns size-sorted full paths of all regular files (including
dotfiles ) that belong to the user's group but not the user and can
be read by the user.

**Remark:** This function is sugar over the zsh native filename
expansion glob and currently only implements part of the former's
functionality.  It is recommended that the user learns the raw glob
flags, as it is one of the most useful features of zsh.  It can
then be invoked in its full flexibility in synth by using something
like
```
⛥ run x '«x=( glob )»' ⇝ ... ⇝ ◎
```
See the function `run` below for more information of invoking
external commands or running raw zsh in synth.

### `seql [start] [end] [step] : Void -> Array(Int)`

**Description:** Creates an arithmetic progression of integers
starting at `start`, ending at `end` and stepping by `step`.  If
`end` is smaller than `start` or if the step is negative, the
stepping occurs backwards.  By default, `start=1, end=10, step=1`.

**Example:** `seql 1 5 -1` produces `(5 4 3 2 1)`, the same as
`seql 5 1`.

### `enter string : Void -> (String)`

**Variant:** `enter '«string»' : Void -> (String)`

**Variant:** `enter whitespace_seperated_strings : Void ->
Array(String)`



**Description:** Populates buffer with a singleton string given by
the input `string`, which cannot contain whitespace.  If the
`string` is wrapped in a literal `'«»'`, then the contents are
executed via the parameter expansion flag `(e)`, thus resolving any
variables and operators like `=`.  In this variant there are no
restrictions on the string (whitespace, special characters etc).

To prevent resolving variables, expansion characters must be
escaped.  On the other hand, escape sequences like `\t` are not
recognized.  In order to do so, add a dollar sign to the outer
quote as `$'«»'` to get ANSI sequence expansion.  

In the third variant, each whitespace separated alphanumeric string
becomes its own array entry.

**Examples:** 

`enter hello` gives the singleton `__buf__=( hello )`.

If the user's name is `foo`, then 
```
enter $'«Hello World!\nThis is $(whoami).»'
``` 
produces the array with the single string entry
```
Hello World!
This is foo.
```

## Direct buffer modification

### `unique : Array(*) -> Array(*)`

**Description:** Removes duplicate entries from the array.
Duplicates must be byte-by-byte identical.

### `duplicate : Array(*) -> Array(*)`

**Description:** Duplicates the buffer, doubling the number of
entries.

**Example:** 
```
⛥ seql 3 ⇝ duplicate ⇝ ◎
```
outputs the array `( 1 2 3 1 2 3 )`.

### `concat [separator] : String^2 -> String`

**Description:** Accepts an array with two string entries, and
concatenates them, optionally separated by [separator].

**Examples:** 
```
⛥ seql 2 ⇝ concat '$wh' ⇝ ◎
```
produces `1 2`.
```
⛥ ... ⇝ foldl concat '«$wh»' ⇝ ◎
```
concatenates all the entries of the buffer into a string, separated
by whitespace.  Note the use of literal quotes in order to avoid
expanding variables in the higher order function `foldl` before
`concat` is properly invoked.

### `encode_all : Array(*) -> Array( string_base64_no_nl )`

**Description:** Encodes each entry of the array as a base64 string
without newlines.

### `decode_all : Array( string_base64_no_nl ) -> Array(*)`

**Description:** Decodes previously encoded array.

### `transpose : Rect_Array(*) -> Rect_Array(*)`

**Description:** Accepts a rectangular array and returns the array
whose rows are the previous array's columns, in the same order.

**Example:**
```
⛥ seql 25  ⇝ segment ⇝ ◎
1 6 11 16 21
2 7 12 17 22
3 8 13 18 23
4 9 14 19 24
5 10 15 20 25

⛥ seql 25  ⇝ segment ⇝ transpose ⇝ ◎
1 2 3 4 5
6 7 8 9 10
11 12 13 14 15
16 17 18 19 20
21 22 23 24 25
```

### `zip : Array(*) -> Array(*)`

**Description:** Takes an array of even size, splits the second
half and intertwines it with the first half by interleaving
even/odd entries.

**Example:** 
`⛥ seql 6  ⇝ zip ⇝ ◎` returns the array `(1 4 2 5 3 6)`.

### `unzip : Array(*) -> Array(*)`

**Description:** Performs the opposite operation of `zip`.

### `extract '«matching_string»' [or fail_output] :
String -> String`

**Variant:** `extract '«matching_string➭:replacement_string»' [or fail_output] :
String -> String` 

**Description:** Extracts the contents of `matching_string`
according to PCRE format, returning the string of matches in words
separated by `$word_delimiter`, or returning a custom replacement
string that accepts entries of `$match`.  If there is no match, it
returns null or optionally the string `fail_output`.  Currently,
the string `fail_output` can only be a simple ASCII string without
any variables or accepting expansion.

**Example:**
```
⛥ seql 7 12 \
	⇝ map extract '«(\d)(\d)➭:Digits: $match[1],$match[2]»' \
		or 'Single digit integer' \
	⇝ ◎ 
Single digit integer
Single digit integer
Single digit integer
Digits: 1,0
Digits: 1,1
Digits: 1,2	
```

### `expand [separator] : String -> Array(String)`

**Description:** Splits the input string according to separator (by
default `$word_delimiter`) and creates an array of the resulting
words.

**Example:**
```
⛥ enter "Hello, World" ⇝ expand '«, »' ⇝ ◎
Hello
World
```

### `contract [separator] : Array(*) -> String`

**Description:** Contracts all the entries in the array into a
string separated by [separator], which is by default
`$word_delimiter`.

**Example:**
```
⛥ seql 5 ⇝ contract - ⇝ ◎
1-2-3-4-5
```
### `dissolve : Array(*) -> Array(char)`

**Description:** First contracts all the entries in the array into a
single string, and then creates an array with one entry for each
character in the string.

**Example:**
```
⛥ seql 10 12 ⇝ dissolve ⇝ ◎ 
```
produces the six-element array `( 1 0 1 1 1 2 )`.

### `prefix [string] : Array(*) -> Array(*)`

**Description:** Prefixes each entry of the array with `string`.
Can be used with `'«string»'`.

### `suffix [string] : Array(*) -> Array(*)`

**Description:** Suffixes each entry of the array with `string`.
Can be used with `'«string»'`.

### `group start,end start,end ... : Array(*) -> Array(*)`

**Description:** Partitions the array into groups given by
intervals of indices.  The groups must be consecutive and must
cover up to the end of the array.  The material effect is that the
k-th group is prefixed with the string `k:`.  This can be then used
with partitioning higher order functions.

**Example:** 
```
⛥ seql 5 ⇝ group 1,2 3,-1 ⇝ ◎
1:1
1:2
2:3
2:4
2:5
```

### `segment [number of columns] : Array(*) -> Rect_Array(*)`

**Description:** Takes an array of size divisible by the parameter
and cuts it into columns of that size, creating a rectangular
array. If the column number is not given, `segment` tries to find
the most square size it can get for the number of columns.  This
will have no effect if, for instance, the array has prime size.  In
that case, the user can pad the array with empty or dummy entries
to make it more square-full before segmenting.

### `unify : Array(*) -> Array(*)`

**Description:** Takes a partitioned array and removes the
partition information.  The partition information is merely a
prefix decoration of the form `String:` where `String`, the
name of the partition, can have any
character except the colon `:`.  This part of the entry is excised
by `unify`.

Example:
```
⛥ seql 3 ⇝ partition mod 2 ⇝ show ⇝ unify ⇝ show
1:1
0:2
1:3
1
2
3
```

### `partialsum [separator] : Array(*) -> Array(*)`

**Description:** Creates an array whose n-th entry is the
concatenation of entries 1 through n of the original array
separated by `separator`, by default `$word_delimiter`.

**Example:**
```
⛥ seql 4 ⇝ partialsum ⇝ ◎
1
1 2
1 2 3
1 2 3 4
```

### `reverse : Array(*) -> Array(*)`

**Description:** Reverses the order of the array's entries.

### `prepend/append [string] : Array(*) -> Array(*)`

**Description:** Prepends or appends the `string` as the new first/last
array entry.  If the string is literal quoted, all variables and
expansions are resolved via the `(e)` flag.

### `prepend_raw/append_raw [string] : Array(*) -> Array(*)`

**Description:** Prepends or appends the `string` as the new first/last
array entry.  Here, no expansion or variable resolution occurs. 

### `lshift/rshift [number] : Array(*) -> Array(*)`

**Description:** Shifts the array to the left (up) or to the right
(down) by `number`, by default 1.  If `number` is negative, shifts
until only `-number` entries remain.

### `rotate [number] : Array(*) -> Array(*)`

**Description:** Rotates array by `number` leftwards (upwards), or
if `number` is negative, rightwards (downwards).

### Search and replace functions on buffer

### `replace [all] string1 string2 : String -> String`

**Variant:** `replace [all] '«string1➭:string2»' : String -> String`

**Description:** Replaces the first, or all, occurrences of
`string1` with `string2` in the input.  The quoted variant allows
for more complex strings and patterns, the rules for replacement
being according to zsh globbing patterns.

### `regex_replace string1 string2 : String -> String`

**Variant 1:** `regex_replace '«string1➭:string2»' : String -> String`
**Variant 2:** `regex '⫽string1⫽string2⫽' : String -> String`

**Description:** As `replace`, but the rules for replacement are
according to PCRE, with the exception that matching groups are not
denoted `\1,\2,...` but `$match[1],$match[2]...`.  The full matched
string is `$MATCH`.  The function `regex_replace` is sugar over the
zsh function `regexp-replace`.

The second variant is a new addition that shortens the call and
uses the more familiar glyph `⫽` for the replacement pattern.  This
triple of glyphs is invoked via `` `/ ``.

## Modifications and replacement functions on records

These functions begin with a capital letter, and are usually meant
to be used in conjunction with `map`.  The corresponding lowercase
functions, which are more frequently used, are aliases for `map
Uppercase`.

### `Over [list of fields] f : String -> String`

**Description:** Takes `f : String -> String` and applies it
field-by-field on the list of fields, which is a
whitespace-separated list of numbers, or the keyword `all`.
Usually used with `map`, so the alias `over='map Over'` is provided.

**Example:**
```
⛥ seql 12 ⇝ segment ⇝ over 2 regex_replace '«(\d)➭:"$match[1]"»' ⇝ ◎
1 "4" 7 10
2 "5" 8 11
3 "6" 9 12
```

### `Swap [pair of fields] : String -> String`

**Description:** Swaps two fields.

**Example:**
```
⛥ enter '«Hello World»' ⇝ swap 1 2  ⇝ ◎
World Hello

word_delimiter=$tb
⛥ enter $'«Hello\tWorld»' ⇝ swap 1 2  ⇝ ◎
World	Hello
```

### `Keep [list of fields] : String -> String`

**Description:** Removes all fields except the listed ones.

### `Excise [list of fields] : String -> String`

**Description:** Removes the listed fields.  Both `Keep` and
`Excise` accept a list of numbers, and negative numbers count from
the last field.

### `Permute [list of fields] : String -> String`

**Description:** Permutes the fields in the record according to the
permutation.  Currently, only complete permutations are accepted,
so if the number of fields is n, the function needs a permutation
of the numbers 1 through n.

### `Freplace [field] string1 string2 : String -> String`

**Variant:** `Freplace [field] '«string1➭:string2»' : String -> String`

**Description:** Replaces `string1` with `string2` at the single
field `field`.  Less verbose than `map Over replace...` but only accepts
one field.  See `replace` and `regex_replace` for details on
string replacement.

### `Regex_freplace [field] string1 string2 : String -> String`

**Variant:** `Regex_freplace [field] '«string1➭:string2»' : String -> String`

**Description:** Replaces `string1` with `string2` at the single
field `field` using PCRE-style regexes.  See `replace` and
`regex_replace` for details on string replacement.

### `actF [+n] field1:var1 field2:var2 ... f : String -> String`

**Description:** Accepts a sequence of field numbers and variables,
puts the field values in the variables, executes f, a function of
the variables, and returns the new variable values to their
respective fields.  Optionally, creates `n` new empty fields at the end
of the input before assigning variable names to fields.  In that
case, the new field count is used to assign the names.

**Example:**
```
⛥ seql 12 ⇝ segment ⇝ show ⇝ actf 1:x 3:y '«y=$((x*y))»' ⇝ ◎ 
1 4 7 10
2 5 8 11
3 6 9 12
1 4 7 10
2 5 16 11
3 6 27 12
```

### Direct execution functions and lambdas

### `λ [ x y z... ] ↦  '«f»' : String^n -> (*)`

**Variant:** `λ [ x y z... ] ↦ '«expr»' : String^n -> (*)`

**Description:** Lambda takes a collection of `n` variables and
executes the expression `expr` which is a function of the
variables, or the function `f` of `n` variables, returning the
result of `expr` to the buffer.  Crucially, `f` is *not* supposed
to be a synthesis atomic function, but a normal zsh function taking
positional parametric input.  This way, lambda becomes an interface
for injecting normal zsh expressions and functions into the
Synthesis pipeline. 

**Examples:**
```
⛥ enter '«Hello World»' ⇝ λ x  ↦ '«echo "String: $x"»' ⇝ ◎
String: Hello World

⛥ seql 5 ⇝ foldl λ x y ↦  '«echo $((x+y))»' ⇝ ◎ 
15

foo(){ print "$1->$(($1+$2))->$(($1+$2+$3))" } #non-synth function

⛥ enter 1 2 3 ⇝ λ x y z  ↦ '«foo $x $y $z»' ⇝ ◎ 
1->3->6

⛥ detect regular read ⇝ map λ x ↦ '«cat -- $x»' 
# Cats all regular readable files in the folder of the invocation 
```

### `run variable '«expression»' : (*) -> Void` 

**Description:** This function takes the given expression,
substitutes every occurrence of `variable` with `__buf__[1]` and
executes the result without returning anything.  
This is a dummy substitution, so *be careful*: in the invocation
```
... run a '«cat $a»'
```
the program will try to execute `c__buf__[1]t $__buf__[1]`.  So
care needs to be taken that the variable name does not occur in the
expression inadvertently.

Although `run` does not return anything by itself, it is simple to
modify the buffer using an expression of the form
```
expression : variable=[other expression]
```

**Examples:** 
```
⛥ run x '«x=(*(D))»' ⇝ ◎	#Shows all files, including dot files

⛥ detect '«*.dat»' ⇝ map run x '«cp -n -- $x ${x%%dat}bak»'
#creates bak files for dat files

⛥ detect '«*.dat»' \
	⇝ map run x '«x=${x%%dat}bak»' \
	⇝ filter x '⟦ -f $x ⟧' \
	⇝ prefix '«File already exists: »' \
	⇝ ◎
	
# Creates a list of .bak filenames and displays messages for those
# that already exist.
```

## Sorting functions

**Warning:** These sorting functions are provided for completeness.
The user is encouraged to use dedicated programs for sorting, which
are much faster and reliable than shell sorting functions or
bespoke sorts.

### `qsort [num/des/ins] : Array(Int/String) ->
Array(Int/String)`

**Description:** Sugar for zsh sort; `num` sorts numerically, `des`
sorts in reverse (descending) order, and `ins` sorts
case-insensitively.  Be warned that zsh numerical sort is on
the decimal digits of the entries, so it cannot properly sort
floats, for instance.  For float sort, the user should use a
dedicated sort function, or as a last resort, the provided `msort`.

### `fsort [field] [num/des/ins] : Array(Int/String) ->
Array(Int/String)`

**Description:** As `qsort` above, but sorts on a given field.

**Example:**
```
⛥ seql 5 ⇝ map x '«x="$x $((x % 2))"»' ⇝ fsort 2 num ⇝ ◎
2 0
4 0
1 1
3 1
5 1
```

### `msort f : Array(*) -> Array(*)`

**Description:** A naive implementation of mergesort with
comparison function `f` being a Boolean Synthesis atomic function
of two variables.  Currently, `f` cannot be a literal expression,
but must be wrapped as a Synthesis function.

**Example:**
```
my_numcomp() {
	lex
	[[ $x[1] -le $x[2] ]] && x="true" || x="false"
	rex
}

⛥ power 50 append '«$RANDOM»' ⇝ map invert ⇝ msort my_numcomp ⇝ ◎

# the comparison above has no problem with floats, so msort
# properly compares the inverses of 50 random integers;
# note that ncomp is already provided by synth for this
```

## Main query functions

These functions take a condition and return true or false depending
on their specification.  They are used with `filter`-like
operators.

### `matching string1 string2 ... : String -> Bool`

**Variant:** `matching '«condition»' : String -> Bool`

**Description:** Returns true if the input string matches all
whitespace-separated strings.  In the second variant (which
subsumes the first via the & operator), a single complex expression
can be given for matching.  The matching is via zsh `=~` test using
PCRE syntax.

### `omitting string1 string2 ... : String -> Bool`

**Variant:** `omitting '«condition»' : String -> Bool`

**Description:** Returns true if the input string omits all strings
as in `matching`.

### `fmatching field1 str1 field2 str2... : String -> Bool`

**Variant:** `fmatching '«field1 str1 field2 str2...»' : String -> Bool`

**Description:** Takes pairs of fields and match strings, and
returns true if all match.  The difference between the two variants
is that the second can accept complex matching patterns that will
be interpreted away by zsh in the first one.  The second pattern
also resolves variables and performs subprocess substitution.

### `fomitting field1 str1 field2 str2... : String -> Bool`

**Variant:** `fomitting '«field1 str1 field2 str2...»' : String -> Bool`

**Description:** As `fmatching`, but returns true if no strings
match.

### `ncomp/scomp : ((Int|Float)/String)^2 -> Bool`

**Description:** Numerical / lexicographic comparisons on pairs of
numbers or strings respectively.  These can be used with `msort`.

## Main arithmetic functions

All the functions in this section are self-explanatory.  They have
the type `fun : (Int|Float)^n -> (Int|Float)` with the usual
caveats about NaN.  The list is:

1. add : (Int|Float)^2 -> (Int|Float) 
2. sub : (Int|Float)^2 -> (Int|Float)
3. mul : (Int|Float)^2 -> (Int|Float)
4. idiv : (Int)^2 -> (Int)
5. rem : (Int)^2 -> (Int)
6. dist : (Int|Float)^2 -> (Int|Float)
7. max : (Int|Float)^2 -> (Int|Float)
8. min : (Int|Float)^2 -> (Int|Float)
9. mod [modulus] : (Int) -> (Int)
10. inc # increment by 1
11. square # square
12. invert # takes reciprocal
13. trans [translate] # translation: adds $1 to the inut
14. scale [scalar] # scalar mult: multiplies input by $1 
15. sroot # square root
16. sum # sums all entries naively
17. prod # multiplies all entries naively

## Main higher order functions

### `map f : Array(*) -> Array(*)`

**Variant:** `map x '«expr»' : Array(*) -> Array(*)`

**Description:** Applies `f` to each element of the array.  `f`
must be an atomic Synthesis function as described in Section 2.1.
Thus lambda is also an acceptable `f`.  In the variant, which
should *not* be confused with lambda, `__buf__[1]`  is substituted
for `x` (or whichever variable name you prefer) in `expr` which is
then executed.  This is the same behavior as `run`.

**Examples:**
```
⛥ seql 5 ⇝ map mod 3 ⇝ ◎
1
2
0
1
2

mkdir back
⛥ detect '«*.dat»' ⇝ map x '«cp -n -- $x back/$x.bak»'
# Backs up dat files to back subfolder with .bak extensions
```

### `filter [out] f : Array(*) -> Array(*)`

**Variant:** `filter [out] x '⟦condition⟧' : Array(*) -> Array(*)`

**Description:** Given a Boolean function `f`, removes array
entries not satisfying `f`, or with the `out` option, removes
entries satisfying `f`.  In the second variant, `x` is an arbitrary
name that appears in `condition`, which automatically creates a zsh
conditional expression.  As with `map` and `run`, `__buf__[1]` is
substituted in all occurrences of `x`, so be careful that your
conditional does not involve the variable name as a substring in an
undesired part.  Recall that the special brackets are invoked via
`` `2 ``.

**Examples:** 
```
⛥ seql 10 ⇝ filter x '⟦ $((x % 3)) -eq 1 ⟧' ⇝ ◎ 
1
4
7
10

⛥ power 5 append '«$RANDOM»' \
	⇝ prefix file ⇝ suffix .dat \
	⇝ filter out x '⟦ -f $x ⟧' \
	⇝ map x '«touch $x»'
	
# creates five filenames file(random number).dat, filters out already
existing files, and creates the rest.

⛥ detect '«/*»' dir ⇝ filter out matching '«(home|run|media|v)»' ⇝ ◎

#Shows top level directories except home, run, media and any
directory with v in its name
```

### `foldl f : Array(*) -> (*)`

**Description:** Accepts a function of two variables compatible
with the types of array entries, and applies it consecutively
accumulating entries until only a singleton is left.  The fold
accumulates from the left.  Note that, for instance, a two-variable
`λ x y  ↦ ...` is an admissible `f`.

**Examples:** 
```
sum() { foldl add } # naive summation is simply a fold of add
prod() { foldl mul } # same for products

sstr() { lex; [[ $x[2] =~ $x[1] ]] && x=$x[2] || x='X'; rex }

⛥ power 10 append '«$RANDOM»' ⇝ foldl sstr ⇝ ◎

# If every number in the array contains the previous number as a
substring, returns the last number.  Otherwise, returns X.  Most
likely returns X.

⛥ power 10 append '«$RANDOM»' ⇝ partialsum ⇝ foldl sstr ⇝ ◎

#Now it never returns X.
```

### `induce [n] f : Array(*) -> Array(*)`

**Description:** `induce` takes a function `f : X -> X` and applies
it to the last entry of the array, appending the result.  Then
repeats this another `n-1` times.  This can also be used to
populate an array.

**Examples:**
```
⛥ enter 1 ⇝ induce 5 scale -2 ⇝ ◎
1
-2
4
-8
16
-32
```

### `fmap [list of fields] f : Array(*) -> Array(*)`

**Variant:** `fmap [list of fields] x '«expr»' : Array(*) -> Array(*)`

**Description:** As `map`, but only applies to the given list of
fields.

### `ffilter [list of fields] f : Array(*) -> Array(*)`

**Variant:** `ffilter [list of fields] x '⟦cond⟧' : Array(*) -> Array(*)`

**Description:** As `filter`, but the condition needs to apply to
each of the given fields.

### `partition f : Array(*) -> Array(*)`

**Variant:** `partition x '«expr»' : Array(*) -> Array(*)`

**Description:** Takes a function `f : X -> String_not_:` that is
applicable to each entry of the array, and returns a string that
does not contain the character ':'.  This string then prefixes the
corresponding array entry separated by ':'.

**Examples:**
```
 seql 5 ⇝ partition mod 3 ⇝ ◎ 
1:1
2:2
0:3
1:4
2:5
```
### `partmap part1:part2:... f : Array(*) -> Array(*)`

**Description:** as `map`, but applies `f` only to the list of
partitions separated by `:`.

**Examples:**
```
⛥ seql 5 ⇝ partition mod 3 ⇝ partmap 1:2 x '«x="Not divisble by 3: $x"»' ⇝ ◎ 
1:Not divisble by 3: 1
2:Not divisble by 3: 2
0:3
1:Not divisble by 3: 4
2:Not divisble by 3: 5
```

### `power n f : Array(*) -> Array(*)`

**Description:** Produces the nth self-composition of `f`.

### `unfold n f : Array(*) -> Array(*)`

**Description:** Takes a function `f : X -> X^2` and applies it
to the last entry in the array; the first output overwrites that
last entry, and then the second output is appended to the array.


### `graphmap f : Array(*) -> Array(*)`

**Description:** Like `map`, but `f : I x X -> X` must be a two
variable function with the first variable an integer.  Then
graphmap applies f to pairs `($index, $__buf__[index])`, that is, to
the "graph" of the array.


### `partfold part f : Array(*) -> Array(*)`

**Description:** Applies `foldl` only to the single part `part` of
the partitioned array.  It retains order by deleting all entries of
the given part except the last entry, where it writes the ultimate
result.

### `foldparts f : Array(*) -> Array(*)`

**Description:** Applies `foldl` to each part, returning an array
with one entry for each part of the partition.

### `Prepend/Append string : Array(*) -> Array(*)`

**Variant 1:** `Prepend/Append f : Array(*) -> Array(*)`

**Variant 2:** `Prepend/Append filename : Array(*) -> Array(*)`

**Description:** These two functions augment the simpler
`prepend/append` functions.  The first variant takes a *buffer
populating function* f, executes it, and appends/prepends the
result to the given array.  The second variant looks for a file
that contains a base64-encoded array, decodes it, and
appends/prepends it to the array.

**Example:**
```
⛥ power 5 append '«$RANDOM»' ⇝ save randfile             
⛥ seql 5  ⇝ prefix '«Random number #»' \
	⇝ suffix '« : »' \
	⇝ Append randfile \
	⇝ segment 2 ⇝ ◎ 
Random number #1 : 15827
Random number #2 : 31204
Random number #3 : 27517
Random number #4 : 28779
Random number #5 : 20865
```

## Main loop

### `synth function1 ⇝ function2 ⇝ ... `

**Description:** This is the main loop.  Invoking either one of the
previously listed functions or a user-created Synthesis function as
described in Section 2.1, it performs consecutive transformations
of an input stream resulting in some output or other action on the
data.  In general, besides the input stream and the command line,
the output of `synth` depends on:

1. Environment variables like `$word_delimiter`, `$input_delimiter`
	 and `$output_delimiter`
2. the definitions of user-created functions
3. contents of variables referenced in the command line
4. OS specific handling of files and memory (especially when the
	 array is very big)

These need to be taken into consideration when executing a synth
command line.

When filtering external data streams, I alias the `synth` function
by `➢`.  The command `dot`, aliased to `•`, simply returns an empty
state for use in `• | ➢`, aliased to `⛥`.

## 2.3. Worked examples

In this section I present solutions to various problems using a
mixture of synthesis and raw zsh code.  In choosing the tasks to
include, I focused on:

a) familiar "toy" problems that allow for immediate comparison of
	synthesis to other workflows;
b) common shell uses involving files, processes and text data
	(here, I am assuming a GNU/Linux OS, as it is the only one I am
	familiar with);
c) somewhat less common uses involving numerical processing,
	especially of tabular data;
d) some simple tasks involving binary data, to showcase zsh's
	capabilities in that domain.

### A simple fizzbuzz

Usage: fizzbuzz [number of elements]
```
fizzbuzz() {
⛥ seql $1 ⇝ partition mod 15 \
					⇝ partmap 3:6:9:12 x '«x=fizz»' \
					⇝ partmap 5:10 x '«x=buzz»' \
					⇝ partmap 0 x '«x="fizz buzz"»' \
					⇝ unify ⇝ ◎ 
}
```
### A fizzbuzz leveraging table manipulations

This is a demo of table manipulation capabilities of synthesis.  It
is not a performant or even sane implementation of fizzbuzz!

Usage: fizz [number of elements]
```
fizz() {
local pad=$(( $1 + 15 - ($1 % 15) ))
local word_delimiter=:

⛥ seql $pad ⇝ segment $(( $pad/3 )) ⇝ transpose ⇝ excise -1\
					  ⇝ suffix ':fizz' ⇝ expand \
	 				  ⇝ segment $(( $pad/5 )) ⇝ transpose ⇝ excise -1\
					  ⇝ suffix ':buzz' ⇝ expand \
	 				  ⇝ segment $(( $pad/15 )) ⇝ transpose ⇝ excise -1\
					  ⇝ suffix ':fizz buzz' ⇝ expand \
					  ⇝ rshift $((pad - $1)) \
					  ⇝ ◎ 
}
```

### Counting the maximum bracket nesting in a file

Given a file with curly-bracket scope, we want to count the maximum
nesting depth of the brackets.
```
nestc() { # Component in maxnest
	lex
	local blob="$x[@]" tally=( 0 0 ) i

	for ((i=1; i <= ${#blob}; i++)); do
		[[ $blob[i] == '{' ]] &&
			(( ++tally[1] )) ||
			(( --tally[1] ))
		[[ $tally[2] -lt $tally[1] ]] &&
			tally[2]=$tally[1]
	done

	ret tally
}

maxnest() {
	< $1 ➢ filter matching '«{|}»' \
		⇝ map regex_replace '«[^{}]➭:»' \
		⇝ reduce concat \
		⇝ nestc ⇝ ◎ 
}
```
### Returning the longest ASCII words in a list
```
longest_words() {
	local word_delimiter=':'

	< $1 ➢  partition x '«x=${#x}»' \
				⇝ fsort 1 num \
				⇝ foldparts concat '«$null»' \
				⇝ lshift -1 \
				⇝ unify \
				⇝ expand '«$null»' ⇝ ◎
}
```

### A simple Fibonacci generator
Don't forget that zsh does not have native bignum, so for large
parameters the generation will break down.
```
fibonacci() {
⛥ enter '«0 1»' \
	⇝ power $1 actF -2:x -1:y '«y="$y $[x+y]"»' \
	⇝ expand ⇝ ◎ 
} 
```
### Listing files with complex criteria

Let's list all non-empty regular files in owned by the user, modified within
the last 2 days, as full paths, recursively over all subfolders of
the current directory.

```
⛥ detect '«**/*»' regular mine lastmod -2 path ⇝ ◎	
```
As another example, let's find all broken symlinks in the directory
tree under the current directory.  The solution is a verbatim copy
of the zsh solution:
```
⛥ detect '«**/*»' Llink ⇝ ◎ 
```
the `L` modifier applies the subsequent criterion to the target of
a symbolic link.  The criterion is that the file *is* a symbolic
link, in which case the link is broken.  This is equivalent to 
```
⛥ detect '«**/*(-@)»' ⇝ ◎ 
```

## 2.4. Performance and stability

The synthesis script was not written with performance in mind;
there are two fundamental issues degrading performance, both quite
hard to overcome:

First, the basic data structure it utilizes, the regular zsh array,
has superlinear access and update time in the index.  In practice,
this means that even traversing an array of 100,000 elements in a
loop takes a noticeable amount of time, and a million item array is
practically inaccessible from a loop.  Since Synthesis relies
heavily on higher order functions and arbitrary user-provided
functions, looping over the buffer multiple times is inevitable.
The solution to this involves switching to an associative array as
the main data structure, with numerical keys to keep order.
Unfortunately, this means implementing all kinds of shifting,
rotating, slicing, etc functions from the ground up, and this would
make the code vastly more complicated.

The second issue, related to the first one, is that most commands
perform full copies of the array or part of the array, process, and
then copy back (`input` and `ret`, for instance, do copies).
Coupled with the fact that in higher order functions, we have at
least one `eval` for each array entry, memory usage and management
cruft accumulates.  This problem would also be mitigated somewhat
with an associative array structure, although proliferation of
`evals` is inevitable when implementing higher order functions in
the shell.

Some suggestions to improve performance include:

1. Do not use overly long arrays; split your task outside the
	 pipeline and create multiple pipelines to be combined if
	 necessary.  This is especially beneficial if the entries are
	 independent of each other.  If your array size starts exceeding
	 100,000, invest in bisection.  Synthesis can both save their
	 buffer in files (which can be then loaded back into another
	 pipeline) and export them in the environment (which can be then
	 accessed by another pipeline).

2. If you find yourself applying a function frequently using `map`,
	 `filter` or other `HOF`, consider writing an array function that
	 accepts the full array and loops natively.  This way you will
	 save yourself thousands of `evals` and possibly spot other
	 shortcuts/optimizations by considering the full array.  

3. You may use Synthesis for quick prototyping, and then drop
	 down to raw zsh for performance.  In the same vein, `zcompile`
	 can sometimes help with script complexity.

Regarding the stability and security in Synthesis: I have made an
effort to isolate the state of the buffer from parametric input,
and avoid interpreting or executing buffer entries, except in the
record interpretation for tables.  If you have sensitive or
unstable data in the buffer, such as filenames or other
uncontrolled input, you need to be careful invoking them in lambdas
or other naked execution contexts.  

Furthermore, note that all HOFs are implemented with `evals` on
command-line input, and buffer contents are passed on to functions
without type checking.  There is an error checking and reporting
system which aborts the pipeline with buffer state information, but
it does not prevent any inadvertent disk writes or system state
modifications prior to failure.

As a general rule of thumb, treat synthesis as any other shell
utility, where malformed user input can have arbitrarily
catastrophic effects on the system!

## 2.5. A note on Unicode

Synthesis uses some unicode symbols for initialization,
termination, gluing and literal quotations.  I find that this
conservative use of unicode makes the core of the code stand out
more; furthermore, since the shell already interprets most ASCII
quotes, I needed some quoting mechanism that can be used alongside
a zsh pipeline, so Unicode quotes were an obvious choice.

The unicode used in synthesis is as follows:

```
«  0x00ab  |  ⟦  0x27e6
»  0x00bb  |  ⟧  0x27e7
⇝  0x21dd  |  ➭  0x27ad
➢  0x27a2  |  λ  0x03bb
•  0x2022  |  ↦  0x21a6
◎  0x25ce  |  ⛥  0x26e5
ψ  0x03c8  |  χ  0x03c7
```

The script provides the following keybindings for quick insertion
(all invocations begin with the backtick `` ` ``; the commands are
double-quoted to distinguish the whitespace):

1. `` `q `` : `"⛥ "`	# q because it is closest to the backtick
2. `` `p `` : `" ⇝ "`	# p for pipe
3. `` `o `` : `"◎ "`	# o for "out"
3. `` `w `` : `" ➢ "`	# w because it is close to backtick
4. `` `\ `` : `" |➢ "`	# \ because it is the key for the unix pipe
5. `` `1 `` : `"'«»'"`	# because it is close to backtick
6. `` `2 `` : `"'⟦⟧'"`	# because it is close to backtick
7. `` `r `` : `"➭:"`	# r for replacement
8. `` `x `` : `"χ"`	# direct Greek analogue
9. `` `l `` : `"λ "`	# direct Greek analogue
10. `` `t ``: `"ψ"`	# t for token in emit function
11. `` `,, ``: `"'«"` # opening literal; prefer `` `1 `` 
11. `` `.. ``: `"»'"` # closing literal; prefer `` `1 `` 

There are more keybindings, but these are sufficient for all synth
pipelines presented in this document.  These keybindings can also
be configured in a text editor / IDE to write pipelines easily.  In
Vim, an example configuration would be:

```
inoremap `p <space>⇝<space>
cnoremap `p <space>⇝<space> "enables typing these symbols in search
```
and so on.

If the user wants to avoid unicode entirely, my suggestions for
alternative notation is as follows:

```
⛥ becomes star
⇝ becomes -to
« becomes l..
» becomes ..l
⟦ becomes q..
⟧ becomes ..q
➭: becomes -rep-
```
and the rest already have non-unicode names.  You can find the
variable definitions in the preamble of the script under the
heading 'Unicode symbols in synth'.


# 3. Copyright and Licence
Copyright © 2021, Ioannis Konstantoulas. All rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
