;;; password-store.el --- Password store (pass) support  -*- lexical-binding: t; -*-

;; Copyright (C) 2014-2019 Svend Sorensen <svend@svends.net>

;; Author: Svend Sorensen <svend@svends.net>
;; Maintainer: Tino Calancha <tino.calancha@gmail.com>
;; Version: 2.1.4
;; URL: https://www.passwordstore.org/
;; Package-Requires: ((emacs "25") (s "1.9.0") (with-editor "2.5.11") (auth-source-pass "5.0.0"))
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

(require 'with-editor)
(require 'auth-source-pass)

(defgroup password-store '()
  "Emacs mode for password-store."
  :prefix "password-store-"
  :group 'password-store)

(defcustom password-store-password-length 25
  "Default password length."
  :group 'password-store
  :type 'number)

(defcustom password-store-time-before-clipboard-restore
  (if (getenv "PASSWORD_STORE_CLIP_TIME")
      (string-to-number (getenv "PASSWORD_STORE_CLIP_TIME"))
    45)
  "Number of seconds to wait before restoring the clipboard."
  :group 'password-store
  :type 'number)

(defcustom password-store-url-field "url"
  "Field name used in the files to indicate an url."
  :group 'password-store
  :type 'string)

(defvar password-store-executable
  (executable-find "pass")
  "Pass executable.")

(defvar password-store-timeout-timer nil
  "Timer for clearing clipboard.")

(defun password-store-timeout ()
  "Number of seconds to wait before clearing the password.

This function just returns `password-store-time-before-clipboard-restore'.
Kept for backward compatibility with other libraries."
  password-store-time-before-clipboard-restore)

(defun password-store--run-1 (callback &rest args)
  "Run pass with ARGS.

Nil arguments are ignored.  Calls CALLBACK with the output on success,
or outputs error message on failure."
  (let ((output ""))
    (make-process
     :name "password-store-gpg"
     :command (cons password-store-executable (delq nil args))
     :connection-type 'pipe
     :noquery t
     :filter (lambda (process text)
               (setq output (concat output text)))
     :sentinel (lambda (process state)
                 (cond
                  ((string= state "finished\n")
                   (funcall callback output))
                  ((string= state "open\n") (accept-process-output process))
                  (t (error (concat "password-store: " state))))))))

(defun password-store--run (&rest args)
  "Run pass with ARGS.

Nil arguments are ignored.  Returns the output on success, or
outputs error message on failure."
  (let ((output nil)
        (slept-for 0))
    (apply #'password-store--run-1 (lambda (password)
                                     (setq output password))
           (delq nil args))
    (while (not output)
      (sleep-for .1))
    output))

(defun password-store--run-async (&rest args)
  "Run pass asynchronously with ARGS.

Nil arguments are ignored.  Output is discarded."
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

(defun password-store--run-show (entry &optional callback)
  (if callback
      (password-store--run-1 callback "show" entry)
    (password-store--run "show" entry)))

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
  (or (bound-and-true-p auth-source-pass-filename)
      (getenv "PASSWORD_STORE_DIR")
      "~/.password-store"))

(defun password-store--entry-to-file (entry)
  "Return file name corresponding to ENTRY."
  (concat (expand-file-name entry (password-store-dir)) ".gpg"))

(defun password-store--file-to-entry (file)
  "Return entry name corresponding to FILE."
  (file-name-sans-extension (file-relative-name file (password-store-dir))))

(defun password-store--completing-read (&optional require-match)
  "Read a password entry in the minibuffer, with completion.

Require a matching password if `REQUIRE-MATCH' is 't'."
  (completing-read "Password entry: " (password-store-list) nil require-match))

(defun password-store-parse-entry (entry)
  "Return an alist of the data associated with ENTRY.

ENTRY is the name of a password-store entry."
  (auth-source-pass-parse-entry entry))

(defun password-store-read-field (entry)
  "Read a field in the minibuffer, with completion for ENTRY."
  (let* ((inhibit-message t)
         (valid-fields (mapcar #'car (password-store-parse-entry entry))))
    (completing-read "Field: " valid-fields nil 'match)))

(defun password-store-list (&optional subdir)
  "List password entries under SUBDIR."
  (unless subdir (setq subdir ""))
  (let ((dir (expand-file-name subdir (password-store-dir))))
    (if (file-directory-p dir)
        (delete-dups
         (mapcar 'password-store--file-to-entry
                 (directory-files-recursively dir ".+\\.gpg\\'"))))))

;;;###autoload
(defun password-store-edit (entry)
  "Edit password for ENTRY."
  (interactive (list (password-store--completing-read t)))
  (password-store--run-edit entry))

;;;###autoload
(defun password-store-get (entry &optional callback)
  "Return password for ENTRY.

Returns the first line of the password data.
When CALLBACK is non-`NIL', call CALLBACK with the first line instead."
  (let* ((inhibit-message t)
         (secret (auth-source-pass-get 'secret entry)))
    (if (not callback) secret
      (password-store--run-show
       entry
       (lambda (_) (funcall callback secret))))))

;;;###autoload
(defun password-store-get-field (entry field &optional callback)
  "Return FIELD for ENTRY.
FIELD is a string, for instance \"url\". 
When CALLBACK is non-`NIL', call it with the line associated to FIELD instead.
If FIELD equals to symbol secret, then this function reduces to `password-store-get'."
  (let* ((inhibit-message t)
         (secret (auth-source-pass-get field entry)))
    (if (not callback) secret
      (password-store--run-show
       entry
       (lambda (_) (and secret (funcall callback secret)))))))


;;;###autoload
(defun password-store-clear (&optional field)
  "Clear secret in the kill ring.

Optional argument FIELD, a symbol or a string, describes
the stored secret to clear; if nil, then set it to 'secret.
Note, FIELD does not affect the function logic; it is only used
to display the message:

\(message \"Field %s cleared.\" field)."
  (interactive "i")
  (unless field (setq field 'secret))
  (when password-store-timeout-timer
    (cancel-timer password-store-timeout-timer)
    (setq password-store-timeout-timer nil))
  (when password-store-kill-ring-pointer
    (setcar password-store-kill-ring-pointer "")
    (setq password-store-kill-ring-pointer nil)
    (message "Field %s cleared." field)))

(defun password-store--save-field-in-kill-ring (entry secret field)
  (password-store-clear field)
  (kill-new secret)
  (setq password-store-kill-ring-pointer kill-ring-yank-pointer)
  (message "Copied %s for %s to the kill ring. Will clear in %s seconds."
           field entry password-store-time-before-clipboard-restore)
  (setq password-store-timeout-timer
        (run-at-time password-store-time-before-clipboard-restore nil
                     (lambda () (funcall #'password-store-clear field)))))

;;;###autoload
(defun password-store-copy (entry)
  "Add password for ENTRY into the kill ring.

Clear previous password from the kill ring.  Pointer to the kill ring
is stored in `password-store-kill-ring-pointer'.  Password is cleared
after `password-store-time-before-clipboard-restore' seconds."
  (interactive (list (password-store--completing-read t)))
  (password-store-get
   entry
   (lambda (password)
     (password-store--save-field-in-kill-ring entry password 'secret))))

;;;###autoload
(defun password-store-copy-field (entry field)
  "Add FIELD for ENTRY into the kill ring.

Clear previous secret from the kill ring.  Pointer to the kill ring is
stored in `password-store-kill-ring-pointer'.  Secret field is cleared
after `password-store-timeout' seconds.
If FIELD equals to symbol secret, then this function reduces to `password-store-copy'."
  (interactive
   (let ((entry (password-store--completing-read)))
     (list entry (password-store-read-field entry))))
  (password-store-get-field
   entry
   field
   (lambda (secret-value)
     (password-store--save-field-in-kill-ring entry secret-value field))))

;;;###autoload
(defun password-store-init (gpg-id)
  "Initialize new password store and use GPG-ID for encryption.

Separate multiple IDs with spaces."
  (interactive (list (read-string "GPG ID: ")))
  (message "%s" (password-store--run-init (split-string gpg-id))))

;;;###autoload
(defun password-store-insert (entry password)
  "Insert a new ENTRY containing PASSWORD."
  (interactive (list (password-store--completing-read)
                     (read-passwd "Password: " t)))
  (let* ((command (format "echo %s | %s insert -m -f %s"
                          (shell-quote-argument password)
                          password-store-executable
                          (shell-quote-argument entry)))
         (ret (process-file-shell-command command)))
    (if (zerop ret)
        (message "Successfully inserted entry for %s" entry)
      (message "Cannot insert entry for %s" entry))
    nil))

;;;###autoload
(defun password-store-generate (entry &optional password-length)
  "Generate a new password for ENTRY with PASSWORD-LENGTH.

Default PASSWORD-LENGTH is `password-store-password-length'."
  (interactive (list (password-store--completing-read)
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
  (interactive (list (password-store--completing-read t)))
  (message "%s" (password-store--run-remove entry t)))

;;;###autoload
(defun password-store-rename (entry new-entry)
  "Rename ENTRY to NEW-ENTRY."
  (interactive (list (password-store--completing-read t)
                     (read-string "Rename entry to: ")))
  (message "%s" (password-store--run-rename entry new-entry t)))

;;;###autoload
(defun password-store-version ()
  "Show version of pass executable."
  (interactive)
  (message "%s" (password-store--run-version)))

;;;###autoload
(defun password-store-url (entry)
  "Browse URL stored in ENTRY."
  (interactive (list (password-store--completing-read t)))
  (let ((url (password-store-get-field entry password-store-url-field)))
    (if url (browse-url url)
      (error "Field `%s' not found" password-store-url-field))))


(provide 'password-store)

;;; password-store.el ends here
