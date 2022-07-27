;;; shell-command+.el --- An extended shell-command -*- lexical-binding: t -*-

;; Copyright (C) 2020-2022  Free Software Foundation, Inc.

;; Author: Philip Kaludercic <philipk@posteo.net>
;; Maintainer: Philip Kaludercic <~pkal/public-inbox@lists.sr.ht>
;; Version: 2.3.2
;; Keywords: unix, processes, convenience
;; Package-Requires: ((emacs "24.1"))
;; URL: https://git.sr.ht/~pkal/shell-command-plus

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; `shell-command+' is a `shell-command' substitute, that extends the
;; regular Emacs command with several features.  After installed,
;; configure the package as follows:
;;
;;	(global-set-key (kbd "M-!") #'shell-command+)
;;
;; A few examples of what `shell-command+' can do:
;;
;;
;; 	> wc -l
;;
;; Count all lines in a buffer, and display the result in the
;; minibuffer.
;;
;;
;;	.. < ls -l
;;
;; Replace the current region (or buffer in no region is selected)
;; with a directory listing of the parent directory.
;;
;;
;;	| tr -d a-z
;;
;; Delete all instances of the charachters a, b, c, ..., z, in the
;; selected region (or buffer, if no region was selected).
;;
;;
;;	man fprintf
;;
;; Open a man-page using Emacs default man page viewer.
;; `shell-command+' can be extended to use custom Elisp handlers via
;; as specified in `shell-command+-substitute-alist'.
;;
;; See `shell-command+'s docstring for more details on how it's input
;; is interpreted.
;;
;; `shell-command+' was originally based on the command `bang' by Leah
;; Neukirchen (https://leahneukirchen.org/dotfiles/.emacs).

;;; News:

;;;; Version 2.3.0 (15Oct21)

;; - Add rgrep to shell-command+-substitute-alist
;; - Fix shell-command+-substitute-alist customization type
;; - Skip environmental variables when parsing a command
;; - Check if command is being piped, in which case command
;;   substitution is avoided.
;; - Fix persistent sudo bug, where any command after a sudo
;;   substitute would try to run as root
;; - Improve command tokenization performance slightly.

;;; Code:

(eval-when-compile (require 'rx))
(eval-when-compile (require 'pcase))
(require 'diff)
(require 'info)
(require 'thingatpt)

(defgroup shell-command+ nil
  "An extended `shell-command'."
  :group 'external
  :prefix "shell-command+-")

(defcustom shell-command+-prompt "Shell command: "
  "Prompt to use when invoking `shell-command+'."
  :type 'string)

(defcustom shell-command+-flip-redirection nil
  "Flip the meaning of < and > at the beginning of a command."
  :type 'boolean)

(defcustom shell-command+-enable-file-substitution t
  "Enable the substitution of \"%s\" with the current file name."
  :type 'boolean)

(defcustom shell-command+-substitute-alist
  '(("grep" . shell-command+-cmd-grep)
    ("fgrep" . shell-command+-cmd-grep)
    ("agrep" . shell-command+-cmd-grep)
    ("egrep" . shell-command+-cmd-grep)
    ("rgrep" . shell-command+-cmd-grep)
    ("find" . shell-command+-cmd-find)
    ("locate" . shell-command+-cmd-locate)
    ("man" . shell-command+-cmd-man)
    ("info" . shell-command+-cmd-info)
    ("diff" . shell-command+-cmd-diff)
    ("make" . compile)
    ("sudo" . shell-command+-cmd-sudo)
    ("cd" . shell-command+-cmd-cd))
  "Association of command substitutes in Elisp.
Each entry has the form (COMMAND . FUNC), where FUNC is passed
the command string.  To disable all command substitutions, set
this option to nil."
  :type '(alist :key-type (string :tag "Command Name")
                :value-type (function :tag "Substitute"))
  :set-after '(shell-command+-use-eshell))

(defcustom shell-command+-default-region nil
  "Default thing to apply a command onto.
The default value nil will apply a buffer to the entire buffer.
A symbol such as `line', `page', `defun', ... as defined by
`bounds-of-thing-at-point' will restrict the region to whatever
is specified."
  :type '(choice (const :tag "Entire buffer" nil)
                 (symbol :tag "Thing")))



(defconst shell-command+-token-regexp
  (rx (* space)
      (or (: ?\"
             (group-n 1 (* (or (: ?\\ anychar) (not (any ?\\ ?\")))))
             ?\")
          (: ?\'
             (group-n 1 (* (or (: ?\\ anychar) (not (any ?\\ ?\')))))
             ?\')
          (group (+ (not (any space ?\\ ?\" ?\')))
                 (* ?\\ anychar (* (not (any space ?\\ ?\" ?\'))))))
      (* space))
  "Regular expression for tokenizing shell commands.")

(defun shell-command+-tokenize (command &optional expand)
  "Return list of tokens of COMMAND.
If EXPAND is non-nil, expand wildcards."
  (let ((pos 0) tokens)
    (while (string-match shell-command+-token-regexp command pos)
      (push (let ((tok (match-string 2 command)))
              (if (and expand tok)
                  (or (file-expand-wildcards tok) (list tok))
                (list (replace-regexp-in-string
                       (rx (* ?\\ ?\\) (group ?\\ (group anychar)))
                       "\\2"
                       (or (match-string 2 command)
                           (match-string 1 command))
                       nil nil 1))))
            tokens)
      (when (= pos (match-end 0))
        (error "Zero-width token parsed"))
      (setq pos (match-end 0)))
    (unless (= pos (length command))
      (error "Tokenization error at %S in string %S (parsed until %d, instead of %d)"
             (substring command pos) command pos (length command)))
    (apply #'append (nreverse tokens))))

(defun shell-command+-cmd-grep (command)
  "Convert COMMAND into a `grep' call."
  (grep-compute-defaults)
  (pcase-let ((`(,cmd . ,args) (shell-command+-tokenize command t)))
    (grep (mapconcat #'identity
                     (cons (replace-regexp-in-string
                            (concat "\\`" grep-program) cmd grep-command)
                           args)
                     " "))))

(defun shell-command+-cmd-find (command)
  "Convert COMMAND into a `find-dired' call."
  (pcase-let ((`(,_ ,dir . ,args) (shell-command+-tokenize command)))
    (find-dired dir (mapconcat #'shell-quote-argument args " "))))

(defun shell-command+-cmd-locate (command)
  "Convert COMMAND into a `locate' call."
  (pcase-let ((`(,_ ,search) (shell-command+-tokenize command)))
    (locate search)))

(defun shell-command+-cmd-man (command)
  "Convert COMMAND into a `man' call."
  (pcase-let ((`(,_ . ,args) (shell-command+-tokenize command)))
    (man (mapconcat #'identity args " "))))

(defun shell-command+-cmd-info (command)
  "Convert COMMAND into a `info' call."
  (pcase-let ((`(,_ . ,args) (shell-command+-tokenize command)))
    (Info-directory)
    (dolist (menu args)
      (Info-menu menu))))

(defun shell-command+-cmd-diff (command)
  "Convert COMMAND into `diff' call."
  (pcase-let ((`(,_ . ,args) (shell-command+-tokenize command t)))
    (let (files flags)
      (dolist (arg args)
        (if (string-match-p (rx bos "-") arg)
            (push arg flags)
          (push arg files)))
      (unless (= (length files) 2)
        (user-error "Usage: diff [file1] [file2]"))
      (pop-to-buffer (diff-no-select (car files)
                                     (cadr files)
                                     flags)))))

(defvar shell-command+--command-regexp)
(defun shell-command+-cmd-sudo (command)
  "Use TRAMP's \"sudo\" method to execute COMMAND."
  (let ((default-directory (concat "/sudo::" default-directory)))
    (unless (string-match shell-command+--command-regexp command)
      (error "Couldn't parse command"))
    (shell-command+ (replace-match "" nil nil command 4))))

(defun shell-command+-cmd-cd (command)
  "Convert COMMAND into a `cd' call."
  (pcase-let ((`(,_ ,directory) (shell-command+-tokenize command)))
    (cd directory)))



(defconst shell-command+--command-regexp
  (rx bos
      ;; Ignore all preceding whitespace
      (* space)
      ;; Check for working directory string
      (? (group (or (: ?. (not (any "/"))) ?/ ?~)
                (* (not space)))
         (+ space))
      ;; Check for redirection indicator
      (? (group (or ?< ?> ?| ?!)))
      ;; Allow whitespace after indicator
      (* space)
      ;; Actual command
      (group
       ;; Skip environmental variables
       (* (: (+ alnum) "=" (or (: ?\" (* (or (: ?\\ anychar) (not (any ?\\ ?\")))) ?\")
                               (: ?\'(* (or (: ?\\ anychar) (not (any ?\\ ?\')))) ?\')
                               (+ (not space))))
          (+ space))
       ;; Command name
       (group (+ (not space)))
       ;; Parse arguments
       (*? space)
       (group (*? not-newline)))
      ;; Ignore all trailing whitespace
      (* space)
      eos)
  "Regular expression to parse `shell-command+' input.")

(defun shell-command+-expand-path (path)
  "Expand any PATH into absolute path with additional tricks.

Furthermore, replace each sequence with three or more `.'s with a
proper upwards directory pointers.  This means that '....' becomes
'../../../..', and so on."
  (expand-file-name
   (replace-regexp-in-string
    (rx (>= 2 "."))
    (lambda (sub)
      (mapconcat #'identity (make-list (1- (length sub)) "..") "/"))
    path)))

(defun shell-command+-parse (command)
  "Return parsed representation of COMMAND.
The resulting list has the form (DIRECTORY INDIRECTION EXECUTABLE
COMMAND), where DIRECTORY is the directory the command should be
executed in, if non-nil, indirection is one of `input', `output',
`pipe', `literal' or nil depending on the indirection-prefix,
executable is the name of the executable, and command is the
entire command."
  (save-match-data
    (unless (string-match shell-command+--command-regexp command)
      (error "Invalid command"))
    (let ((dir (match-string-no-properties 1 command))
          (ind (cond ((string= (match-string-no-properties 2 command) "<")
                      (if shell-command+-flip-redirection
                          'output 'input))
                     ((string= (match-string-no-properties 2 command) ">")
                      (if shell-command+-flip-redirection
                          'input 'output))
                     ((string= (match-string-no-properties 2 command) "|")
                      'pipe)
                     ((or (string= (match-string-no-properties 2 command) "!")
                          ;; Check if the output of the command is being
                          ;; piped into some other command. In that case,
                          ;; interpret the command literally.
                          (let ((args (match-string-no-properties 5 command)))
                            (save-match-data
                              (member "|" (shell-command+-tokenize args)))))
                      'literal)))
          (cmd (match-string-no-properties 4 command))
          (all (condition-case nil
                   (if shell-command+-enable-file-substitution
                       (replace-regexp-in-string
                        (rx (* ?\\ ?\\) (or ?\\ (group "%")))
                        buffer-file-name
                        (match-string-no-properties 3 command)
                        nil nil 1)
                     (match-string-no-properties 3 command))
                 (error (match-string-no-properties 3 command)))))
      (if (or (null dir) (file-directory-p dir))
          (list dir ind cmd all)
        (list nil ind dir (format "%s %s" dir all))))))

;;;###autoload
(defun shell-command+ (command &optional beg end)
  "Intelligently execute string COMMAND in inferior shell.

If COMMAND is prefixed with an absolute or relative path, the
created process will the executed in the specified path.

When COMMAND starts with...
  <  the output of COMMAND replaces the current selection
  >  COMMAND is run with the current selection as input
  |  the current selection is filtered through COMMAND
  !  COMMAND is simply executed (same as without any prefix)

If the first word in COMMAND, matches an entry in the alist
`shell-command+-substitute-alist', the respective function is
used to execute the command instead of passing it to a shell
process.  This behaviour can be inhibited by prefixing COMMAND
with !.

Inside COMMAND, % is replaced with the current file name.  To
insert a literal % quote it using a backslash.

These extentions can all be combined with one-another.

In case a region is active, `shell-command+' will only work with the region
between BEG and END.  Otherwise the whole buffer is processed."
  (interactive (let ((bounds (and shell-command+-default-region
                                  (bounds-of-thing-at-point
                                   shell-command+-default-region))))
                 (list (read-shell-command
                        (if (bound-and-true-p shell-command-prompt-show-cwd)
                            (format shell-command+-prompt
                                    (abbreviate-file-name default-directory))
                          shell-command+-prompt))
                       (cond ((use-region-p) (region-beginning))
                             (bounds (car bounds))
                             ((point-min)))
                       (cond ((use-region-p) (region-end))
                             (bounds (cdr bounds))
                             ((point-max))))))
  (pcase-let* ((`(,path ,mode ,command ,rest) (shell-command+-parse command))
               (default-directory (shell-command+-expand-path (or path "."))))
    ;; Make sure the previous output buffer was killed, to prevent
    ;; TRAMP paths from persisting between commands.
    (let ((shell-command-buffer (get-buffer (or (bound-and-true-p shell-command-buffer-name)
                                                "*Shell Command Output*"))))
      (when shell-command-buffer
        (kill-buffer shell-command-buffer)))
    (cond ((eq mode 'input)
           (delete-region beg end)
           (shell-command rest t shell-command-default-error-buffer)
           (exchange-point-and-mark))
          ((eq mode 'output)
           (shell-command-on-region
            beg end rest nil nil
            shell-command-default-error-buffer t))
          ((eq mode 'pipe)
           (shell-command-on-region
            beg end rest t t
            shell-command-default-error-buffer t))
          ((and (not (eq mode 'literal))
                (assoc command shell-command+-substitute-alist))
           (funcall (cdr (assoc command shell-command+-substitute-alist))
                    rest))
          (t (shell-command rest (and current-prefix-arg t)
                            shell-command-default-error-buffer)))))

(provide 'shell-command+)

;;; shell-command+.el ends here
