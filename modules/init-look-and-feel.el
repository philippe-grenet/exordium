;;; init-look-and-feel.el --- Look and feel -*- lexical-binding: t -*-

;;; Commentary:
;;
;; Keyboard preferences: remaps existing functions to new keys
;;
;; ----------------- ---------------------------------------------------------
;; Key               Definition
;; ----------------- ---------------------------------------------------------
;; ESC               Quit (= Ctrl-G)
;; M-g               Goto line
;; C-z               Undo
;; C-`               Kill current buffer (= C-x k)
;;
;; RETURN            Return or Return + indent, depending on init-prefs
;; S-RETURN          The opposite
;;
;; M-C-l             Switch to last buffer
;; C-x C-b           Buffer menu with `ibuffer', replacing `list-buffers'
;; C- +/-            Zoom

;; C-=               Expand region by semantic units
;; M-C-=             Contract region by semantic units
;;
;; M-<up>            Move selected region up
;; M-<down>          Move selected region down
;;
;; F10               Speedbar
;; ----------------- ---------------------------------------------------------

;;; Code:
(eval-when-compile
  (unless (featurep 'init-require)
    (load (file-name-concat (locate-user-emacs-file "modules") "init-require"))))
(exordium-require 'init-prefs)

(require 'cl-lib)

;;; Font

(defun exordium-available-preferred-fonts ()
  "Trim the unavailable fonts from the preferred font list."
  (cl-remove-if-not (lambda (font-and-size)
                      (member (car font-and-size) (font-family-list)))
                    exordium-preferred-fonts))

(defun exordium-font-size ()
  "Find the available preferred font size."
  (when (exordium-available-preferred-fonts)
    (cdar (exordium-available-preferred-fonts))))

(defun exordium-font-name ()
  "Find the avaliable preferred font name."
  (when (exordium-available-preferred-fonts)
    (caar (exordium-available-preferred-fonts))))

(defun exordium-set-font (&optional font size)
  "Find the preferred fonts that are available and choose the first one.
Set FONT and SIZE if they are passed as arguments."
  (interactive
   (list (completing-read (format "Font (default %s): " (exordium-font-name))
                          (exordium-available-preferred-fonts) nil nil nil nil
                          (exordium-font-name))
         (read-number "Size: " (exordium-font-size))))
  (let ((font (or font (exordium-font-name)))
        (size (or size (exordium-font-size))))
    (when (and font size)
      (message "Setting font family: %s, height: %s" font size)
      (set-face-attribute 'default nil
                          :family font
                          :height size
                          :weight 'normal)
      t))) ;; indicate that the font has been set

(when exordium-preferred-fonts
  (exordium-set-font))

(if (daemonp)
    (add-hook 'server-after-make-frame-hook #'exordium-set-font))

;;; User interface

;;; Default frame size
(when (and exordium-preferred-frame-width
           exordium-preferred-frame-height)
  (setq default-frame-alist `((width  . ,exordium-preferred-frame-width)
                              (height . ,exordium-preferred-frame-height))))

;;; Remove the toolbar
(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))

;;; Only show the menu bar in a graphical window
;;; (we don't want to loose that top line in a tty)
(menu-bar-mode (if (null (window-system)) -1 1))

;;; Remove welcome message
(setq inhibit-startup-message t)

;;; Disable blinking cursor
(when (fboundp 'blink-cursor-mode)
  (blink-cursor-mode -1))

;;; Display column number in the modebar
(column-number-mode 1)

;;; Smooth scrolling
(setq scroll-step 1)
(setq scroll-margin 0
      scroll-conservatively 100000
      scroll-up-aggressively 0.01
      scroll-down-aggressively 0.01
      scroll-preserve-screen-position t)

;;; Scrollbar
(when (fboundp 'set-scroll-bar-mode)
  (if exordium-scroll-bar
      (set-scroll-bar-mode `right)
    (set-scroll-bar-mode nil)))

;;; Better frame title with buffer name
(setq frame-title-format (concat "%b - emacs@" (system-name)))

;;; Disable beep
;;(setq visual-bell t)

;;; Colorize selection
(transient-mark-mode 'on)

;;; Show matching parentheses
(use-package paren
  :ensure nil
  :if (version< emacs-version "29")
  :config
  (show-paren-mode t))

(use-package paren
  :ensure nil
  :if (version<= "29" emacs-version)
  :functions (exordium--show-paren-tune-child-frame-context)
  :init
  (defun exordium--show-paren-tune-child-frame-context (&rest _)
    "Set face `child-frame-border' and add matching paren overlay."
    (when-let* ((frame show-paren--context-child-frame)
                (overlay-face (overlay-get show-paren--overlay-1 'face)))
      (set-face-attribute 'child-frame-border frame
                          :background
                          (face-attribute overlay-face :background nil t))
      (when-let* (((eq show-paren-style 'parenthesis))
                  (data (funcall show-paren-data-function))
                  (pos (min (nth 0 data) (nth 2 data)))
                  (pos (save-excursion
                         ;; The following is adjusted from
                         ;; `blink-paren-open-paren-line-string'
                         (goto-char pos)
                         (cond
                          ;; Context is what precedes the open in its line, if
                          ;; anything.
                          ((save-excursion (skip-chars-backward " \t")
                                           (not (bolp)))
                           (- (1+ pos) (line-beginning-position)))
                          ;; Context is what follows the open in its line, if
                          ;; anything
                          ((save-excursion (forward-char 1)
                                           (skip-chars-forward " \t")
                                           (not (eolp)))
                           1)
                          ;; Context is the previous nonblank line, if there is
                          ;; one.
                          ((save-excursion (skip-chars-backward "\n \t")
                                           (not (bobp)))
                           (+  (- (- (progn (skip-chars-backward "\n \t")
                                            (line-beginning-position))
                                     (progn (end-of-line)
                                            (skip-chars-backward " \t")
                                            (point))))
                              4)) ; regions are concatenated with "..."
                          ;; There is no context except the char itself.
                          (t 1))))
                  ((< 0 pos))
                  (win (frame-root-window frame))
                  (buffer (window-buffer win)))
        (move-overlay show-paren--overlay pos (1+ pos) buffer)
        (overlay-put show-paren--overlay 'priority show-paren-priority)
        (overlay-put show-paren--overlay 'face overlay-face))))

  :custom
  (show-paren-context-when-offscreen 'child-frame)
  :config
  ;; Make border for context in child frame a little bit more prominent
  (setf (alist-get 'child-frame-border-width
                   show-paren--context-child-frame-parameters)
        2)
  (setf (alist-get 'font
                   show-paren--context-child-frame-parameters)
        (exordium-font-name))
  (advice-add 'show-paren--show-context-in-child-frame
              :after #'exordium--show-paren-tune-child-frame-context)
  (show-paren-mode t))

;;; Mouse selection
(use-package select
  :ensure nil
  :custom
  (select-enable-clipboard t))

;;; http://www.reddit.com/r/emacs/comments/30g5wo/the_kill_ring_and_the_clipboard/
(setq save-interprogram-paste-before-kill t)

;;; Electric pair: automatically close parenthesis, curly brace etc.
;;; `electric-pair-open-newline-between-pairs'.
(when exordium-enable-electric-pair-mode
  (setq electric-pair-open-newline-between-pairs t)
  (electric-pair-mode))

;;; Indent with spaces, not tabs
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)

;;; Autofill at 79 characters
(setq-default fill-column 79)

;;; Wordwrap at word boundadies
;;;(global-visual-line-mode 1)

;; Show only 1 window on startup (useful if you open multiple files)
(add-hook 'emacs-startup-hook #'delete-other-windows t)

;; Remove surrounding quotes for link buttons and stick to the same window
(use-package help
  :ensure nil
  :defer t
  :custom
  (help-clean-buttons t)
  (help-window-keep-selected t))


;;; Keyboard preferences

;; Use ESC as Control-G
(when exordium-keyboard-escape
  (bind-key "ESC" #'keyboard-quit))

;;; Use "y or n" answers instead of full words "yes or no"
(when exordium-enable-y-or-n
  (fset 'yes-or-no-p 'y-or-n-p))

;;; Delete selection when typing
(delete-selection-mode t)

;;; Let me scroll the buffer while searching, without exiting the search.
;;; This allows for using C-l during isearch.
(when (boundp 'isearch-allow-scroll)
  (setq isearch-allow-scroll t))

;;; Evil-mode
(if exordium-enable-evil-mode
    (use-package evil
      :commands (evil-mode)
      :config
      (evil-mode))
  ;; Evil mode depends in undo-tree, which thinks it should work by default
  (when (fboundp 'global-undo-tree-mode)
    (global-undo-tree-mode -1)))

(defun insert-gui-primary-selection ()
  "If no region is selected, insert current gui selection at point."
  (interactive)
  (when (not (use-region-p))
    (let ((text (gui-get-selection)))
      (when text
        (push-mark (point))
        (insert-for-yank text)))))

(when exordium-enable-insert-gui-primary-selection
  (bind-key "M-<insert>" #'insert-gui-primary-selection))


;;; Shortcut keys

(bind-key "M-g" #'goto-line)
(when exordium-keyboard-ctrl-z-undo
  (bind-key "C-z" #'undo))
(bind-key "C-`" #'kill-current-buffer)

;;; Meta-Control-L = switch to last buffer
(defun switch-to-other-buffer ()
  "Alternates between the two most recent buffers."
  (interactive)
  (switch-to-buffer (other-buffer)))

(bind-key "M-C-l" #'switch-to-other-buffer)

;;; C-x C-b = ibuffer (better than list-buffers)
(bind-key "C-x C-b" #'ibuffer)

;;; Zoom
(use-package default-text-scale
  :bind
  ("C-+" . #'default-text-scale-increase)
  ("C--" . #'default-text-scale-decrease)
  ("C-<mouse-4>" . #'default-text-scale-increase)
  ("C-<mouse-5>" . #'default-text-scale-decrease))

;;; CUA.
;;; CUA makes C-x, C-c and C-v cut/copy/paste when a region is selected.
;;; Adding shift or doubling the Ctrl-* makes it switch back to Emacs keys.
;;; It also has a nice feature: C-RET for selecting rectangular regions.
;;; If exordium-enable-cua-mode is nil, only the rectangular regions are enabled.
(cond ((eq exordium-enable-cua-mode :region)
       (cua-selection-mode t))
      (exordium-enable-cua-mode
       (cua-mode t)))


;;; Cool extensions

;;; Expand region
(use-package expand-region
  :bind
  (("C-=" . #'er/expand-region)
   ("C-M-=" . #'er/contract-region)))

;;; Move regions up and down (from https://www.emacswiki.org/emacs/MoveRegion)
(defun move-region (start end n)
  "Move the current region from START to END up or down by N lines."
  (interactive "r\np")
  (let ((line-text (delete-and-extract-region start end)))
    (forward-line n)
    (let ((start (point)))
      (insert line-text)
      (setq deactivate-mark nil)
      (set-mark start))))

(defun move-region-up (start end n)
  "Move the current region from START to END up by N lines."
  (interactive "r\np")
  (move-region start end (if (null n) -1 (- n))))

(defun move-region-down (start end n)
  "Move the current region from START to END down by N lines."
  (interactive "r\np")
  (move-region start end (if (null n) 1 n)))

(bind-key "M-<up>" #'move-region-up)
(bind-key "M-<down>" #'move-region-down)


;;; File saving and opening

;; Warn when opening files bigger than 100MB (use nil to disable it entirely)
(setq large-file-warning-threshold 100000000)

;; Propose vlf (Very Large File) as a choice when opening large files
;; (otherwise one can open a file using M-x vlf):
(use-package vlf-setup
  :ensure vlf
  :defer t)

;; Remove trailing blanks on save
(define-minor-mode delete-trailing-whitespace-mode
  "Remove trailing whitespace upon saving a buffer."
  :lighter nil
  (if delete-trailing-whitespace-mode
      (add-hook 'before-save-hook #'delete-trailing-whitespace nil t)
    (remove-hook 'before-save-hook #'delete-trailing-whitespace t)))

(define-globalized-minor-mode global-delete-trailing-whitespace-mode
  delete-trailing-whitespace-mode
  (lambda ()
    (delete-trailing-whitespace-mode t))
  :group 'exordium)

(when exordium-delete-trailing-whitespace
  (global-delete-trailing-whitespace-mode t))

;;; Disable backup files (e.g. file~)
(defun no-backup-files ()
  "Disable creation of backup files."
  (interactive)
  (setq make-backup-files nil))

(unless exordium-backup-files
  (no-backup-files))


(provide 'init-look-and-feel)

;;; init-look-and-feel.el ends here
