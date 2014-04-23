;;; password-store.el --- Password store (pass) support

;; Copyright (C) 2014 Svend Sorensen <svend@ciffer.net>

;; Author: Svend Sorensen <svend@ciffer.net>
;; Version: 0.1
;; Package-Requires: ((f "0.11.0") (s "1.9.0"))
;; Keywords: pass

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
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

;; This package provides functions for working with pass ("the
;; standard Unix password manager").
;;
;; http://www.zx2c4.com/projects/password-store/

;;; Code:

(require 'f)
(require 's)

(defvar pass-executable
  (executable-find "pass")
  "Pass executable.")

(defconst password-store-password-length 8
  "Default password length.")

(defconst password-store-timeout 45
  "Number of seconds to wait before clearing the password.")

(defun password-store--run (&rest args)
  "Run pass with ARGS.

Returns the output on success, or outputs error message on
failure."
  (with-temp-buffer
    (let ((exit-code
	   (apply 'call-process
		  (append
		   (list pass-executable nil (current-buffer) nil)
		   args))))
      (if (zerop exit-code)
	  (buffer-string)
	(error (s-chomp (buffer-string)))))))

(defvar password-store-kill-ring-pointer nil
  "The tail of of the kill ring ring whose car is the password.")

(defun password-store-dir ()
  "Return password store directory."
  (or (getenv "PASSWORD_STORE_DIR")
      "~/.password-store"))

(defun password-store--entry-to-file (entry)
  "Return file name corresponding to ENTRY."
  (concat (f-join (password-store-dir) entry) ".gpg"))

(defun password-store--file-to-entry (file)
  "Return entry name corresponding to FILE."
  (f-no-ext (f-relative file (password-store-dir))))

(defun password-store-list (&optional subdir)
  "List password entries under SUBDIR."
  (unless subdir (setq subdir ""))
  (let ((dir (f-join (password-store-dir) subdir)))
    (if (f-directory? dir)
	(mapcar 'password-store--file-to-entry
		(f-files dir (lambda (file) (equal (f-ext file) "gpg")) t)))))

;;;###autoload
(defun password-store-edit (entry)
  "Edit password for ENTRY.

This edits the password file directly in Emacs, so changes will
need to be commited manually if git is being used."
  (interactive (list (completing-read "Password entry: " (password-store-list))))
  (find-file (password-store--entry-to-file entry)))

;;;###autoload
(defun password-store-get (entry)
  "Return password for ENTRY.

Returns the first line of the password data."
  (car (s-lines (password-store--run "show" entry))))

;;;###autoload
(defun password-store-clear ()
  "Clear password in kill ring."
  (interactive)
  (if password-store-kill-ring-pointer
      (progn
	(setcar password-store-kill-ring-pointer "")
	(setq password-store-kill-ring-pointer nil)
	(message "Password cleared."))))

;;;###autoload
(defun password-store-copy (entry)
  "Add password for ENTRY to kill ring.

Clear previous password from kill ring.  Pointer to kill ring is
stored in `password-store-kill-ring-pointer'.  Password is cleared
after `password-store-timeout' seconds."
  (interactive (list (completing-read "Password entry: " (password-store-list))))
  (let ((password (password-store-get entry)))
    (password-store-clear)
    (kill-new password)
    (setq password-store-kill-ring-pointer kill-ring-yank-pointer)
    (message "Copied %s to the kill ring. Will clear in %s seconds." entry password-store-timeout)
    (run-at-time password-store-timeout nil 'password-store-clear)))

;;;###autoload
(defun password-store-generate (entry &optional password-length)
  "Generate a new password for ENTRY with PASSWORD-LENGTH.

Default PASSWORD-LENGTH is `password-store-password-length'."
  (interactive (list (read-string "Password entry: ")
		     (when current-prefix-arg
		       (abs (prefix-numeric-value current-prefix-arg)))))
  (unless password-length (setq password-length password-store-password-length))
  ;; A message with the output of the command is not printed because
  ;; the output contains the password.
  (password-store--run "generate" "-f" entry (number-to-string password-length))
  nil)

;;;###autoload
(defun password-store-insert (entry password)
  "Insert a new ENTRY containing PASSWORD."
  (interactive (list (read-string "Password entry: ")
		     (read-passwd "Password: " t)))
  (message (s-chomp (shell-command-to-string (format "echo %s | %s insert -m -f %s" password pass-executable entry)))))

;;;###autoload
(defun password-store-remove (entry)
  "Remove existing password for ENTRY."
  (interactive (list (completing-read "Password entry: " (password-store-list))))
  (message (s-chomp (password-store--run "rm" "-f" entry))))

;;;###autoload
(defun password-store-url (entry)
  "Browse URL stored in ENTRY.

This will only browse URLs that start with http:// or http:// to
avoid sending a password to the browser."
  (interactive (list (completing-read "Password entry: " (password-store-list))))
  (let ((url (password-store-get entry)))
    (if (or (string-prefix-p "http://" url)
	    (string-prefix-p "https://" url))
	(browse-url url)
      (error "%s" "String does not look like a URL"))))

;;;###autoload
(defun password-store-version ()
  "Show version of pass executable."
  (interactive)
  (message (s-chomp (password-store--run "version"))))

;;; password-store.el ends here
