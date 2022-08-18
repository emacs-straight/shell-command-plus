.POSIX:
.PHONY: all compile test clean
.SUFFIXES: .el .elc

EMACS = emacs
BYTEC = shell-command+.elc

all: compile

compile: $(BYTEC)

test: compile
	$(EMACS) --version
	$(EMACS) -Q --batch -L . -l shell-command+-tests.el -f ert-run-tests-batch-and-exit

clean:
	$(RM) $(BYTEC) compat.info

.el.elc:
	$(EMACS) -Q --batch -L . -f batch-byte-compile $<
