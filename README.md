`shell-command+.el`
===================

`shell-command+` is a `shell-command` substitute that makes it easier
to run commands on regions or whole buffers, among other things.

`shell-command+` has been based on a function named `bang` by [Leah
Neukirchen][leah].

How to use
----------

`shell-command+` is available from [ELPA]. It can be installed by
invoking

	M-x package-install RET shell-command+ RET

Bind the command `shell-command+` to any key, for example `M-!`.

Using [`setup`][setup] I configure `shell-command+` as so:

~~~elisp
(setup (:package shell-command+)
  (:option (remove shell-command+-features) #'shell-command+-implicit-cd
           shell-command+-prompt "$ ")
  (:bind-into dired "M-!" shell-command+)
  (:global "M-!" shell-command+))
~~~

Bugs
----

Bugs or comments can be submitted to my [public inbox][mail].  Note
that non-trivial contributions require a [copyright assignment][ca] to
the FSF.

Copying
-------

`shell-command+.el` is distributed under the [GPL v3][gpl3] license.

[leah]: http://leahneukirchen.org/dotfiles/.emacs
[ELPA]: http://elpa.gnu.org/packages/shell-command+.html
[mail]: https://lists.sr.ht/~pkal/public-inbox
[setup]: http://elpa.gnu.org/packages/setup.html
[ca]: https://www.gnu.org/software/emacs/manual/html_node/emacs/Copyright-Assignment.html#Copyright-Assignment
[gpl3]: https://www.gnu.org/licenses/gpl-3.0.en.html
