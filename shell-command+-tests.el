;;; shell-command+-tests.el --- Tests for shell-command+  -*- lexical-binding: t; -*-

;; Copyright (C) 2021  Philip Kaludercic

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

(ert-deftest sc+-path ()
  "Make sure a simple command with an argument is recognized."
  (pcase-let* ((`(,path ,mode ,command ,rest)
                (shell-command+-parse "... command arg arg2")))
    (should (string= path "..."))
    (should (null mode))
    (should (string= command "command"))
    (should (string= rest "command arg arg2"))))

(ert-deftest sc+-path2 ()
  "Make sure a simple command with an argument is recognized."
  (pcase-let* ((`(,path ,mode ,command ,rest)
                (shell-command+-parse ".../dir command arg arg2")))
    (should (string= path ".../dir"))
    (should (null mode))
    (should (string= command "command"))
    (should (string= rest "command arg arg2"))))

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

(ert-deftest sc+-input-and-path ()
  "Check if input and path conflict."
  (pcase-let* ((`(,path ,mode ,command ,rest)
                (shell-command+-parse "... < command arg arg2")))
    (should (string= "..." path))
    (should (eq mode 'input))
    (should (string= command "command"))
    (should (string= rest "command arg arg2"))))

(ert-deftest sc+-output-and-path ()
  "Check if output and path conflict."
  (pcase-let* ((`(,path ,mode ,command ,rest)
                (shell-command+-parse "... > command arg arg2")))
    (should (string= "..." path))
    (should (eq mode 'output))
    (should (string= command "command"))
    (should (string= rest "command arg arg2"))))

(ert-deftest sc+-pipe-and-path ()
  "Check if pipe and path conflict."
  (pcase-let* ((`(,path ,mode ,command ,rest)
                (shell-command+-parse "... | command arg arg2")))
    (should (string= "..." path))
    (should (eq mode 'pipe))
    (should (string= command "command"))
    (should (string= rest "command arg arg2"))))

(ert-deftest sc+-file-replace ()
  "Check if %'s are replaced."
  (pcase-let* ((buffer-file-name "somefile")
               (`(,path ,mode ,command ,rest)
                   (shell-command+-parse "command %")))
    (should (null path))
    (should (null mode))
    (should (string= command "command"))
    (should (string= rest (concat "command " buffer-file-name)))))

(ert-deftest sc+-file-noreplace ()
  "Check if %'s are replaced."
  (pcase-let* ((`(,path ,mode ,command ,rest)
                (shell-command+-parse "command \\%")))
    (should (null path))
    (should (null mode))
    (should (string= command "command"))
    (should (string= rest (concat "command \\%")))))

(ert-deftest sc+-expand ()
  "Test that `shell-command+-expand-path' works as expected"
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

(provide 'shell-command+-tests)
;;; shell-command+-tests.el ends here
