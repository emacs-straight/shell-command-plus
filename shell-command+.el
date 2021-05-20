;;; shell-command+.el --- An extended shell-command -*- lexical-binding: t -*-

;; Copyright (C) 2020  Free Software Foundation, Inc.

;; Author: Philip K. <philipk@posteo.net>
;; Version: 2.1.0
;; Keywords: unix, processes, convenience
;; Package-Requires: ((emacs "24.1"))
;; URL: https://git.sr.ht/~zge/bang

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
;;
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
;; Open a man-page using Emacs default man page viewer.  This feature
;; is based on `eshell', and can be customized using
;; `shell-command+-use-eshell'.
;;
;; See `shell-command+'s docstring for more details on how it's input
;; is interpreted..

(eval-when-compile (require 'rx))
(eval-when-compile (require 'pcase))
(require 'eshell)
(require 'em-unix)

;;; Code:

(defgroup shell-command+ nil
  "An extended `shell-command'"
  :group 'external
  :prefix "shell-command+-")

(defcustom shell-command+-use-eshell t
  "Check for eshell handlers.
If t, always invoke eshell handlers.  If a list, only invoke
handlers if the symbol (eg. `man') is contained in the list."
  :type '(choice (boolean :tag "Always active?")
                 (repeat :tag "Selected commands" symbol)))

(defcustom shell-command+-prompt "Shell command: "
  "Prompt to use when invoking `shell-command+'."
  :type 'string)

(defconst shell-command+--command-regexp
  (rx bos
      ;; ignore all preceding whitespace
      (* space)
      ;; check for working directory string
      (? (group (or (: ?. (not (any "/"))) ?/ ?~)
                (* (not space)))
         (+ space))
      ;; check for redirection indicator
      (? (or (group ?<) (group ?>) (group ?|) ?!))
      ;; allow whitespace after indicator
      (* space)
      ;; actual command (and command name)
      (group (group (+ (not space)))
             (*? space)
             (*? not-newline))
      ;; ignore all trailing whitespace
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
  "Return parsed representation of COMMAND."
  (save-match-data
    (unless (string-match shell-command+--command-regexp command)
      (error "Invalid command"))
    (list (match-string-no-properties 1 command)
          (cond ((match-string-no-properties 2 command) ;<
                 'input)
                ((match-string-no-properties 3 command) ;>
                 'output)
                ((match-string-no-properties 4 command) ;|
                 'pipe))
          (match-string-no-properties 6 command)
          (condition-case nil
              (replace-regexp-in-string
               (rx (* ?\\ ?\\) (or ?\\ (group "%")))
               buffer-file-name
               (match-string-no-properties 5 command)
               nil nil 1)
            (error (match-string-no-properties 5 command))))))

(shell-command+-parse "ls %")

;;;###autoload
(defun shell-command+ (command beg end)
  "Intelligently execute string COMMAND in inferior shell.

If COMMAND is prefixed with an absolute or relative path, the
created process will the executed in the specified path.

When COMMAND starts with...
  <  the output of COMMAND replaces the current selection
  >  COMMAND is run with the current selection as input
  |  the current selection is filtered through COMMAND
  !  COMMAND is simply executed (same as without any prefix)

If `shell-command+-use-eshell' is non-nil, and the the first
argument of COMMAND has a defined `eshell'-function, use that.

Inside COMMAND, % is replaced with the current file name.  To
insert a literal % quote it using a backslash.

These extentions can all be combined with one-another.

In case a region is active, `shell-command+' will only work with the region
between BEG and END.  Otherwise the whole buffer is processed."
  (interactive (list (read-shell-command shell-command+-prompt)
                     (if (use-region-p) (region-beginning) (point-min))
                     (if (use-region-p) (region-end) (point-max))))
  (pcase-let* ((`(,path ,mode ,command ,rest) (shell-command+-parse command))
               (default-directory (shell-command+-expand-path (or path "."))))
    (cond ((eq mode 'input)
           (delete-region beg end)
           (shell-command rest t shell-command-default-error-buffer)
           (exchange-point-and-mark))
          ((eq mode 'output)
           (shell-command-on-region
            beg end rest nil nil
            shell-command-default-error-buffer t))
          ((eq mode 'pipe)              ;|
           (shell-command-on-region
            beg end rest t t
            shell-command-default-error-buffer t))
          ((and (or (eq shell-command+-use-eshell t)
                    (memq (intern command) shell-command+-use-eshell))
                (intern-soft (concat "eshell/" command)))
           (eshell-command rest (and current-prefix-arg t)))
          (t (shell-command rest (and current-prefix-arg t)
                            shell-command-default-error-buffer)))))

(provide 'shell-command+)

;;; shell-command+.el ends here
