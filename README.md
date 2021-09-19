## About synthesis

Synthesis is a zsh script for emulating a functional-pattern coding
style in the shell, with higher order functions, lambdas and
functional composition (Greek: synthesis) at the forefront.

For example, an elementary fizzbuzz in synthesis would look like
this:
```
fizzes=77 # however many iterations we want

⛥ seql $fizzes ⇝ partition mod 15 \
			⇝ partmap 3:6:9:12 enter '«fizz»' \
			⇝ partmap 5:10 enter '«buzz»' \
			⇝ partmap 0 enter '«fizz buzz»' \
			⇝ unify ⇝ ◎ 
```

The following code creates/updates backup files of text files
belonging to the user that were accessed within the last two days:
```
⛥ detect '«./*.txt»' mine lastacc -2 \
			⇝ map run x '«cp -- $x $x.bak»'
```
The unicode symbols have two-keystroke keymaps for ease of input,
as well as suggested non-unicode replacements.  For instance, ⛥ is
inputted by `` `q `` (backtick-q) and the pipe arrow ⇝ by `` `p ``.

The script was created for my personal use, inspired by previous
efforts to provide functional templates in the shell, and then
expanded into a more generic tool over the course of the last
couple of months.  It is an amateur project so please be very
careful if you decide to use it.

For more information, credits, caveats etc, check the documentation
in `documentation.md`.  Both the script and the documentation are
works in progress.

## Installation

Clone this repository locally and source the file `synthesis.zsh`.  Note
that the file contains escape sequences for some of the keybindings
in order to reposition the cursor; looking at the raw file from
the browser, these sequences are stripped off.  If the keybindings
`` `1 `` and `` `2 `` do not properly position the cursor in the
center of the brackets, you need to supply these keystrokes at the
bindkeys near the end of the file.

The documentation has more information on the prerequisites and
first steps into this environment.
