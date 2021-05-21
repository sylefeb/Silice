;;; silice-mode.el --- Major mode for Silice

;;; Commentary:

;; A major mode providing some syntax highlighting for the Silice programming language.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Dependency

;;; Code:

(defgroup silice nil
  "Major mode for editing Silice code."
  :link '(custom-group-link :tag "Font lock faces group" font-lock-faces)
  :group 'languages)

(defconst silice-font-lock-keywords
  '(("\\(\\(\\$\\$[^\n]*?$\\)\\|\\(\\$include\\([^\n]*?\\)$\\)\\|\\(\\$[^z-a]*?\\$\\)\\)"
     0 font-lock-preprocessor-face prepend)
    ;; preprocessor
    ("\\b\\(uninitiali\\(s|z\\)ed\\|import\\|algorithm\\|input\\|output\\|inout\\|if\\|else\\|while\\|autorun\\|auto\\|onehot\\|\\+\\+:\\|brom\\|bram\\|dualport_bram\\|case\\|default\\|break\\|switch\\|circuitry\\|always\\|bitfield\\|interface\\|subroutine\\|readwrites\\|reads\\|writes\\|calls\\)\\b"
     . font-lock-keyword-face)
    ;; keywords
    ("\\(@\\|!\\)\\([[:alpha:]]\\|_\\)\\([[:alnum:]]\\|_\\)+"
     . font-lock-function-name-face)
    ;; algorithm meta-specifiers
    ("\\b\\(__\\(display\\|write\\|\\(un\\)?signed\\)\\|widthof\\|sameas\\)\\b"
     . font-lock-builtin-face)
    ;; intrisics
    ("\\b\\(u?int\\([[:digit:]]+\\)?\\)\\b"
     . font-lock-type-face)
    ;; builtin types
    ("\".*?\""
     . font-lock-string-face)
    ("'.*?'"
     . font-lock-string-face)
    ;; strings
    ("[[:digit:]]+\\(b\\|h\\|d\\)[[:xdigit:]]+"
     . font-lock-constant-face)
    ("[[:digit:]]+"
     . font-lock-constant-face)
    ;; numbers
    )
  "Additional expressions to highlight in Silice mode.")

(defvar silice-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?\n "> b" st)
    (modify-syntax-entry ?/  ". 124b" st)
    (modify-syntax-entry ?*  ". 23" st)
    (modify-syntax-entry ?_  "w" st)
    (modify-syntax-entry ?$  "_" st)
    (modify-syntax-entry ?\" "|" st)
    (modify-syntax-entry ?'  "|" st)
;    NOTE: this somehow breaks the font locks defined for the preprocessor if they contain strings
    st)
  "Syntax table used while in Silice mode.")

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ice\\.lpp\\'" . silice-mode))
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ice\\'" . silice-mode))
;;;###autoload
(define-derived-mode silice-mode prog-mode "Silice"
  "Major mode for editing simple Silice source files.
Only provides syntax highlighting."
  :syntax-table silice-mode-syntax-table

  (setq-local font-lock-defaults '(silice-font-lock-keywords))

  (setq-local comment-start "//")
  (setq-local comment-add 1)
  (setq-local comment-end "")

  (setq-local comment-start-skip "\\(?:\\s<+\\|/[/*]+\\)[ \t]*")
  (setq-local comment-end-skip "[ \t]*\\(\\s>\\|\\*+/\\)")

  (setq-local comment-multi-line 1)
  )


(provide 'silice-mode)

;;; silice-mode.el ends here
