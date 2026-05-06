;;; icloud-to-org-contacts.el --- CardDAV contacts to Org -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Sean McLaren

;; Author: Sean McLaren
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: outlines, tools, contacts
;; URL: https://github.com/smclaren727/icloud-to-org-contacts

;;; Commentary:

;; Thin Emacs wrapper around the icloud-to-org-contacts CLI.
;;
;; Install the CLI first, then add this directory to `load-path' and
;; require this package.  The commands run asynchronously and write
;; output to `icloud-to-org-contacts-buffer-name'.

;;; Code:

(require 'subr-x)

(defgroup icloud-to-org-contacts nil
  "Import CardDAV and vCard contacts into Org notes."
  :group 'applications
  :prefix "icloud-to-org-contacts-")

(defcustom icloud-to-org-contacts-command nil
  "Optional path to the icloud-to-org-contacts executable.
When nil, find `icloud-to-org-contacts' on `exec-path'."
  :type '(choice (const :tag "Find on exec-path" nil)
                 file)
  :group 'icloud-to-org-contacts)

(defcustom icloud-to-org-contacts-output-directory
  (expand-file-name "Contacts" user-emacs-directory)
  "Directory where generated contact Org files are written."
  :type 'directory
  :group 'icloud-to-org-contacts)

(defcustom icloud-to-org-contacts-carddav-server-url
  "https://contacts.icloud.com"
  "CardDAV server URL used by `icloud-to-org-contacts-sync-carddav'."
  :type 'string
  :group 'icloud-to-org-contacts)

(defcustom icloud-to-org-contacts-carddav-auth-machine nil
  "Optional authinfo machine name for CardDAV credentials.
When nil, the CLI uses its default authinfo lookup."
  :type '(choice (const :tag "CLI default" nil)
                 string)
  :group 'icloud-to-org-contacts)

(defcustom icloud-to-org-contacts-carddav-groups nil
  "Optional list of CardDAV group UIDs or exact names to sync."
  :type '(repeat string)
  :group 'icloud-to-org-contacts)

(defcustom icloud-to-org-contacts-buffer-name "*icloud-to-org-contacts*"
  "Name of the buffer used for importer process output."
  :type 'string
  :group 'icloud-to-org-contacts)

(defun icloud-to-org-contacts--executable ()
  "Return the configured icloud-to-org-contacts executable."
  (or icloud-to-org-contacts-command
      (executable-find "icloud-to-org-contacts")
      (user-error "Cannot find icloud-to-org-contacts executable")))

(defun icloud-to-org-contacts--display-command (command)
  "Return a shell-like display string for COMMAND."
  (string-join (mapcar #'shell-quote-argument command) " "))

(defun icloud-to-org-contacts--run (label args)
  "Run the contacts importer with LABEL and ARGS."
  (let* ((buffer (get-buffer-create icloud-to-org-contacts-buffer-name))
         (command (cons (icloud-to-org-contacts--executable) args)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "%s\n\n$ %s\n\n"
                        label
                        (icloud-to-org-contacts--display-command command))))
      (special-mode))
    (display-buffer buffer)
    (make-process
     :name "icloud-to-org-contacts"
     :buffer buffer
     :command command
     :sentinel #'icloud-to-org-contacts--sentinel)))

;;;###autoload
(defun icloud-to-org-contacts-import-vcf (input)
  "Import vCard data from INPUT into Org contact notes.

INPUT is a path to a `.vcf' file or to a directory of `.vcf' files."
  (interactive
   (list (read-file-name "Import VCF file or directory: " nil nil t)))
  (unless (file-exists-p input)
    (user-error "Input not found: %s" input))
  (let ((resolved-input (expand-file-name input))
        (output-directory
         (expand-file-name icloud-to-org-contacts-output-directory)))
    (icloud-to-org-contacts--run
     (format "Importing %s\n  -> %s" resolved-input output-directory)
     (list "import-vcf" resolved-input "-o" output-directory))))

;;;###autoload
(defun icloud-to-org-contacts-sync-carddav (&optional full-refresh)
  "Sync CardDAV contacts into Org contact notes.

With prefix argument FULL-REFRESH, rewrite all managed contacts."
  (interactive "P")
  (let ((args (list "sync-carddav"
                    "-o"
                    (expand-file-name
                     icloud-to-org-contacts-output-directory)
                    "--server-url"
                    icloud-to-org-contacts-carddav-server-url)))
    (when full-refresh
      (setq args (append args (list "--full-refresh"))))
    (when icloud-to-org-contacts-carddav-auth-machine
      (setq args (append args (list
                               "--auth-machine"
                               icloud-to-org-contacts-carddav-auth-machine))))
    (dolist (group icloud-to-org-contacts-carddav-groups)
      (setq args (append args (list "--group" group))))
    (icloud-to-org-contacts--run
     (format "Syncing CardDAV contacts\n  -> %s"
             (expand-file-name icloud-to-org-contacts-output-directory))
     args)))

;;;###autoload
(defun icloud-to-org-contacts-list-groups ()
  "List CardDAV contact groups in `icloud-to-org-contacts-buffer-name'."
  (interactive)
  (let ((args (list "list-groups"
                    "--server-url"
                    icloud-to-org-contacts-carddav-server-url)))
    (when icloud-to-org-contacts-carddav-auth-machine
      (setq args (append args (list
                               "--auth-machine"
                               icloud-to-org-contacts-carddav-auth-machine))))
    (icloud-to-org-contacts--run "Listing CardDAV contact groups" args)))

(defun icloud-to-org-contacts--sentinel (proc event)
  "Append process status EVENT for PROC to its output buffer."
  (when (memq (process-status proc) '(exit signal))
    (let ((trimmed (string-trim event)))
      (when-let ((buffer (process-buffer proc)))
        (with-current-buffer buffer
          (let ((inhibit-read-only t))
            (goto-char (point-max))
            (insert (format "\n[process %s]\n" trimmed)))))
      (message "icloud-to-org-contacts: %s" trimmed))))

(provide 'icloud-to-org-contacts)
;;; icloud-to-org-contacts.el ends here
