`bang.el`
=========

`shell-command+` is a `shell-command` substitute that makes it easier
to run commands on regions or whole buffers, among other things.

`shell-command+` has been based on a function named `bang` by [Leah
Neukirchen][leah].

Features
--------

Usually `shell-command+` acts just like `shell-command`, but in
certain cases, `shell-command+` pre-processes the input. Here are a
few examples of what that might look like:

 	> wc -l

Count all lines in a buffer, and display the result in the
minibuffer.

	.. < ls -l

Replace the current region (or buffer in no region is selected)
with a directory listing of the parent directory.

	| tr -d a-z

Delete all instances of the charachters a, b, c, ..., z, in the
selected region (or buffer, if no region was selected).

	.../src make

Run Eshell's make (via `compile`) in the parent's parent
directory, and then in `src`.


How to use
----------

`shell-command+` is available from [ELPA]. It can be installed by
invoking

	M-x package-install RET shell-command+ RET

Bind the command `shell-command+` to any key, for example `M-!`.

Bug reports and patches should be sent to my [public inbox].

Copying
-------

`bang.el` is distributed under the [CC0 1.0 Universal (CC0 1.0) Public
Domain Dedication][cc0] license.

[leah]: http://leahneukirchen.org/dotfiles/.emacs
[ELPA]: http://elpa.gnu.org/packages/shell-command+.html
[public inbox]: https://lists.sr.ht/~zge/public-inbox
[cc0]: https://creativecommons.org/publicdomain/zero/1.0/deed
