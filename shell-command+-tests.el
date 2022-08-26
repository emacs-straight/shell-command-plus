;;; shell-command+-tests.el --- Tests for shell-command+  -*- lexical-binding: t; -*-

;; Copyright (C) 2021, 2022  Free Software Foundation, Inc.

;; Author: Philip Kaludercic <philipk@posteo.net>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Tests for the `shell-command+' parsers.
;;
;; FIXME: Due to the changes in 93233c9g a number of tests have been
;; disabled (see 834c026) that made implicit assumptions on the
;; internal structure of the code.  These tests should eventually be
;; added back to improve the automated testing.

;;; Code:

(require 'ert)
(require 'shell-command+)
(require 'pcase)

(ert-deftest sc+-basic ()
  "Make sure a simple command is recognized."
  (pcase-let* ((`(,path ,mode ,command ,rest)
                (shell-command+-parse "command")))
    (should (null path))
    (should (null mode))
    (should (string= command "command"))
    (should (string= rest "command"))))

(ert-deftest sc+-basic2 ()
  "Make sure a simple command with an argument is recognized."
  (pcase-let* ((`(,path ,mode ,command ,rest)
                (shell-command+-parse "command arg")))
    (should (null path))
    (should (null mode))
    (should (string= command "command"))
    (should (string= rest "command arg"))))

(ert-deftest sc+-basic3 ()
  "Make sure a simple command with an argument is recognized."
  (pcase-let* ((`(,path ,mode ,command ,rest)
                (shell-command+-parse "command arg arg2")))
    (should (null path))
    (should (null mode))
    (should (string= command "command"))
    (should (string= rest "command arg arg2"))))

;; (ert-deftest sc+-path ()
;;   "Make sure a simple command with an argument is recognized."
;;   (pcase-let* ((`(,path ,mode ,command ,rest)
;;                 (shell-command+-parse "... command arg arg2")))
;;     (should (string= path "..."))
;;     (should (null mode))
;;     (should (string= command "command"))
;;     (should (string= rest "command arg arg2"))))

;; (ert-deftest sc+-path2 ()
;;   "Make sure a simple command with an argument is recognized."
;;   (pcase-let* ((`(,path ,mode ,command ,rest)
;;                 (shell-command+-parse ".../dir command arg arg2")))
;;     (should (string= path ".../dir"))
;;     (should (null mode))
;;     (should (string= command "command"))
;;     (should (string= rest "command arg arg2"))))

(ert-deftest sc+-input ()
  "Make sure input is recognized."
  (pcase-let* ((`(,path ,mode ,command ,rest)
                (shell-command+-parse "< command arg arg2")))
    (should (null path))
    (should (eq mode 'input))
    (should (string= command "command"))
    (should (string= rest "command arg arg2"))))

(ert-deftest sc+-output ()
  "Make sure output is recognized."
  (pcase-let* ((`(,path ,mode ,command ,rest)
                (shell-command+-parse "> command arg arg2")))
    (should (null path))
    (should (eq mode 'output))
    (should (string= command "command"))
    (should (string= rest "command arg arg2"))))

(ert-deftest sc+-pipe ()
  "Make sure pipe is recognized."
  (pcase-let* ((`(,path ,mode ,command ,rest)
                (shell-command+-parse "| command arg arg2")))
    (should (null path))
    (should (eq mode 'pipe))
    (should (string= command "command"))
    (should (string= rest "command arg arg2"))))

;; (ert-deftest sc+-input-and-path ()
;;   "Check if input and path conflict."
;;   (pcase-let* ((`(,path ,mode ,command ,rest)
;;                 (shell-command+-parse "... < command arg arg2")))
;;     (should (string= "..." path))
;;     (should (eq mode 'input))
;;     (should (string= command "command"))
;;     (should (string= rest "command arg arg2"))))

;; (ert-deftest sc+-output-and-path ()
;;   "Check if output and path conflict."
;;   (pcase-let* ((`(,path ,mode ,command ,rest)
;;                 (shell-command+-parse "... > command arg arg2")))
;;     (should (string= "..." path))
;;     (should (eq mode 'output))
;;     (should (string= command "command"))
;;     (should (string= rest "command arg arg2"))))

;; (ert-deftest sc+-pipe-and-path ()
;;   "Check if pipe and path conflict."
;;   (pcase-let* ((`(,path ,mode ,command ,rest)
;;                 (shell-command+-parse "... | command arg arg2")))
;;     (should (string= "..." path))
;;     (should (eq mode 'pipe))
;;     (should (string= command "command"))
;;     (should (string= rest "command arg arg2"))))

;; (ert-deftest sc+-file-replace ()
;;   "Check if %'s are replaced."
;;   (pcase-let* ((buffer-file-name "somefile")
;;                (`(,path ,mode ,command ,rest)
;;                    (shell-command+-parse "command %")))
;;     (should (null path))
;;     (should (null mode))
;;     (should (string= command "command"))
;;     (should (string= rest (concat "command " buffer-file-name)))))

;; (ert-deftest sc+-file-noreplace ()
;;   "Check if %'s are replaced."
;;   (pcase-let* ((`(,path ,mode ,command ,rest)
;;                 (shell-command+-parse "command \\%")))
;;     (should (null path))
;;     (should (null mode))
;;     (should (string= command "command"))
;;     (should (string= rest (concat "command \\%")))))

(ert-deftest sc+-expand ()
  "Test that `shell-command+-expand-path' works as expected."
  (let ((default-directory "/some/path/to/dir"))
    (pcase-dolist (`(,path . ,expand)
                   '(("."                       . "/some/path/to/dir")
                     (".."                      . "/some/path/to")
                     ("..."                     . "/some/path")
                     (".../dir"                 . "/some/path/dir")
                     (".../dir/..../else"        . "/else")
                     ("....."                   . "/")))
      (should (string= (shell-command+-expand-path path)
                       expand)))))

(ert-deftest sc+-tokenize ()
  "Test that `shell-command+-tokenize' works as expected."
  (pcase-dolist (`(,args ,expand ,list)
                 '(("a b c" nil ("a" "b" "c"))
                   ("a \"b c\" d" nil ("a" "b c" "d"))
                   ("a *.el d" nil ("a" "*.el" "d"))
                   ("a *.el d" t ("a"
                                  ".dir-locals.el"
                                  "shell-command+-tests.el"
                                  "shell-command+.el"
                                  "d"))
                   ("a b *.el" nil ("a" "b" "*.el"))
                   ("a b *.el" t ("a" "b"
                                  ".dir-locals.el"
                                  "shell-command+-tests.el"
                                  "shell-command+.el"))
                   ("a \"*.el\" d" nil ("a" "*.el" "d"))
                   ("a \"*.el\" d" t ("a" "*.el" "d"))
                   ("a \"b\\ c\" d" nil ("a" "b c" "d"))
                   ("a \"b\\\" c\" d" nil ("a" "b\" c" "d"))
                   ("a \"b\\\" \\\"c\" d" nil ("a" "b\" \"c" "d"))
                   ("a b \\c d" nil ("a" "b" "c" "d"))
                   ("a b \\cd" nil ("a" "b" "cd"))
                   ("a b\\ c d" nil ("a" "b c" "d"))
                   ("a b\\c d" nil ("a" "bc" "d"))
                   ("a b\\ c d" nil ("a" "b c" "d"))
                   ("a b\\\\c d" nil ("a" "b\\c" "d"))
                   ("a b\\\\ c d" nil ("a" "b\\" "c" "d"))
                   ("a b\\\\\\ c d" nil ("a" "b\\\\ c" "d"))
                   ("abcd\\ ef gh" nil ("abcd ef" "gh"))
                   ("abcd\\ ef  gh" nil ("abcd ef" "gh"))
                   ("abcd\\ ef  gh " nil ("abcd ef" "gh"))
                   (" abcd\\ ef  gh  " nil ("abcd ef" "gh"))))
    (should (equal (shell-command+-tokenize args expand)
                   list))))

(provide 'shell-command+-tests)
;;; shell-command+-tests.el ends here
