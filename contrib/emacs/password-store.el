;;; password-store.el --- Password store (pass) support

;; Copyright (C) 2014-2017 Svend Sorensen <svend@svends.net>

;; Author: Svend Sorensen <svend@svends.net>
;; Version: 1.0.1
;; URL: https://www.passwordstore.org/
;; Package-Requires: ((emacs "24") (f "0.11.0") (s "1.9.0") (with-editor "2.5.11"))
;; Keywords: tools pass password password-store

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
;; http://www.passwordstore.org/

;;; Code:

(require 'f)
(require 's)
(require 'with-editor)

(defgroup password-store '()
  "Emacs mode for password-store."
  :prefix "password-store-"
  :group 'password-store)

(defcustom password-store-password-length 8
  "Default password length."
  :group 'password-store
  :type 'number)

(defvar password-store-executable
  (executable-find "pass")
  "Pass executable.")

(defvar password-store-timeout-timer nil
  "Timer for clearing clipboard.")

(defun password-store-timeout ()
  "Number of seconds to wait before clearing the password."
  (if (getenv "PASSWORD_STORE_CLIP_TIME")
      (string-to-number (getenv "PASSWORD_STORE_CLIP_TIME"))
    45))

(defun password-store--run (&rest args)
  "Run pass with ARGS.

Nil arguments are ignored.  Returns the output on success, or
outputs error message on failure."
  (with-temp-buffer
    (let* ((tempfile (make-temp-file ""))
           (exit-code
            (apply 'call-process
                   (append
                    (list password-store-executable nil (list t tempfile) nil)
                    (delq nil args)))))
      (unless (zerop exit-code)
        (erase-buffer)
        (insert-file-contents tempfile))
      (delete-file tempfile)
      (if (zerop exit-code)
          (s-chomp (buffer-string))
        (error (s-chomp (buffer-string)))))))

(defun password-store--run-async (&rest args)
  "Run pass asynchronously with ARGS.

Nil arguments are ignored."
  (let ((args (mapcar #'shell-quote-argument args)))
    (with-editor-async-shell-command
     (mapconcat 'identity
                (cons password-store-executable
                      (delq nil args)) " "))))

(defun password-store--run-init (gpg-ids &optional folder)
  (apply 'password-store--run "init"
         (if folder (format "--path=%s" folder))
         gpg-ids))

(defun password-store--run-list (&optional subdir)
  (error "Not implemented"))

(defun password-store--run-grep (&optional string)
  (error "Not implemented"))

(defun password-store--run-find (&optional string)
  (error "Not implemented"))

(defun password-store--run-show (entry)
  (password-store--run "show"
                       entry))

(defun password-store--run-insert (entry password &optional force)
  (error "Not implemented"))

(defun password-store--run-edit (entry)
  (password-store--run-async "edit"
                             entry))

(defun password-store--run-generate (entry password-length &optional force no-symbols)
  (password-store--run "generate"
                       (if force "--force")
                       (if no-symbols "--no-symbols")
                       entry
                       (number-to-string password-length)))

(defun password-store--run-remove (entry &optional recursive)
  (password-store--run "remove"
                       "--force"
                       (if recursive "--recursive")
                       entry))

(defun password-store--run-rename (entry new-entry &optional force)
  (password-store--run "rename"
                       (if force "--force")
                       entry
                       new-entry))

(defun password-store--run-copy (entry new-entry &optional force)
  (password-store--run "copy"
                       (if force "--force")
                       entry
                       new-entry))

(defun password-store--run-git (&rest args)
  (apply 'password-store--run "git"
         args))

(defun password-store--run-version ()
  (password-store--run "version"))

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

(defun password-store--completing-read ()
  "Read a password entry in the minibuffer, with completion."
  (completing-read "Password entry: " (password-store-list)))

(defun password-store-list (&optional subdir)
  "List password entries under SUBDIR."
  (unless subdir (setq subdir ""))
  (let ((dir (f-join (password-store-dir) subdir)))
    (if (f-directory? dir)
        (mapcar 'password-store--file-to-entry
                (f-files dir (lambda (file) (equal (f-ext file) "gpg")) t)))))

;;;###autoload
(defun password-store-edit (entry)
  "Edit password for ENTRY."
  (interactive (list (password-store--completing-read)))
  (password-store--run-edit entry))

;;;###autoload
(defun password-store-get (entry)
  "Return password for ENTRY.

Returns the first line of the password data."
  (car (s-lines (password-store--run-show entry))))

;;;###autoload
(defun password-store-clear ()
  "Clear password in kill ring."
  (interactive)
  (when password-store-timeout-timer
    (cancel-timer password-store-timeout-timer)
    (setq password-store-timeout-timer nil))
  (when password-store-kill-ring-pointer
    (setcar password-store-kill-ring-pointer "")
    (setq password-store-kill-ring-pointer nil)
    (message "Password cleared.")))

;;;###autoload
(defun password-store-copy (entry)
  "Add password for ENTRY to kill ring.

Clear previous password from kill ring.  Pointer to kill ring is
stored in `password-store-kill-ring-pointer'.  Password is cleared
after `password-store-timeout' seconds."
  (interactive (list (password-store--completing-read)))
  (let ((password (password-store-get entry)))
    (password-store-clear)
    (kill-new password)
    (setq password-store-kill-ring-pointer kill-ring-yank-pointer)
    (message "Copied %s to the kill ring. Will clear in %s seconds." entry (password-store-timeout))
    (setq password-store-timeout-timer
          (run-at-time (password-store-timeout) nil 'password-store-clear))))

;;;###autoload
(defun password-store-init (gpg-id)
  "Initialize new password store and use GPG-ID for encryption.

Separate multiple IDs with spaces."
  (interactive (list (read-string "GPG ID: ")))
  (message "%s" (password-store--run-init (split-string gpg-id))))

;;;###autoload
(defun password-store-insert (entry password)
  "Insert a new ENTRY containing PASSWORD."
  (interactive (list (read-string "Password entry: ")
                     (read-passwd "Password: " t)))
  (message "%s" (shell-command-to-string
                 (format "echo %s | %s insert -m -f %s"
                         (shell-quote-argument password)
                         password-store-executable
                         (shell-quote-argument entry)))))

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
  (password-store--run-generate entry password-length t)
  nil)

;;;###autoload
(defun password-store-remove (entry)
  "Remove existing password for ENTRY."
  (interactive (list (password-store--completing-read)))
  (message "%s" (password-store--run-remove entry t)))

;;;###autoload
(defun password-store-rename (entry new-entry)
  "Rename ENTRY to NEW-ENTRY."
  (interactive (list (password-store--completing-read)
                     (read-string "Rename entry to: ")))
  (message "%s" (password-store--run-rename entry new-entry t)))

;;;###autoload
(defun password-store-version ()
  "Show version of pass executable."
  (interactive)
  (message "%s" (password-store--run-version)))

;;;###autoload
(defun password-store-url (entry)
  "Browse URL stored in ENTRY.

This will only browse URLs that start with http:// or http:// to
avoid sending a password to the browser."
  (interactive (list (password-store--completing-read)))
  (let ((url (password-store-get entry)))
    (if (or (string-prefix-p "http://" url)
            (string-prefix-p "https://" url))
        (browse-url url)
      (error "%s" "String does not look like a URL"))))

(provide 'password-store)

;;; password-store.el ends here
