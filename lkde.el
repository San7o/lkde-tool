;; -------------------------------------------------------------------
;;  LKDE
;;  by Giovanni Santini | giovanni.santini@proton.me
;; -------------------------------------------------------------------


(setq lkde-env "linux")
(setq lkde-base-dir "~/lkde")

(defun lkde-set-env ()
  ;; Set the lkde-env variable
  (interactive)
  (let ((env (read-from-minibuffer "Set environment to: ")))
    (setq lkde-env env)
    (message (concat "Set lkde-env variable to " env))))

(defun lkde-set-base-dir ()
  ;; Set the lkde-env variable
  (interactive)
  (let ((base-dir (read-directory-name "Set lkde base directory to: ")))
    (setq lkde-base-dir base-dir)
    (message (concat "Set lkde-base-dir variable to " base-dir))))

(defun lkde-command ()
  ;; Run an interactive command with default-directory set to env's SOURCE_DIR
  (interactive)
  (let ((default-directory (shell-command-to-string
                     (concat "ENV=" lkde-env " make -C " lkde-base-dir " -s source-dir")))
        (command (intern (completing-read "Enter command: " obarray 'commandp t))))
      (call-interactively command)))

(defun lkde ()
  ;; Run a shell command
  (interactive)
  (let* ((default (concat "ENV=" lkde-env " make -C " lkde-base-dir " "))
         (command (read-from-minibuffer "Shell command: " default)))
    (async-shell-command command)))

(provide 'lkde)
