;;; silice-mode.el --- Major mode for Silice

;;; Commentary:

;; A major mode providing some syntax highlighting for the Silice programming language.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Dependency

(require 'rx)
(require 'font-lock)

;;; Code:

(defgroup silice nil
  "Major mode for editing Silice code."
  :link '(custom-group-link :tag "Font lock faces group" font-lock-faces)
  :group 'languages)

(defconst silice-keywords
  '("uninitialized"
    "uninitialised"
    "import"
    "algorithm"
    "input"
    "output"
    "inout"
    "if" "else"
    "while"
    "autorun" "auto" "onehot"
    "brom" "bram" "dualport_bram" "simple_dualport_bram"
    "case" "switch" "default" "break"
    "circuitry"
    "always" "always_before" "always_after"
    "bitfield" "interface" "subroutine" "group"
    "readwrites" "reads" "writes" "calls"
    "goto" "return"
    "isdone")
  "List of Silice keywords.")

(defconst silice-formal-keywords
  '("assertstable" "assert"
    "assumestable" "assume"
    "restrict"
    "wasin"
    "stableinput"
    "cover"
    "depth" "timeout" "mode")
  "List of silice formal keywords.")


(defconst silice-font-lock-keywords
  `((,(rx-to-string '(: "$" (| (: "include" "(" (*? anychar) ")")
                              (: (+? not-newline) "$")
                              (: "$" (*? not-newline) "\n"))))
     0 font-lock-preprocessor-face prepend)
    ;; preprocessor
    (,(rx-to-string `(: "#" (? (: (| ,@silice-formal-keywords) eow))))
     . font-lock-preprocessor-face)
    ;; formal stuff
    (,(rx-to-string `(: bow (| ,@silice-keywords) eow))
     . font-lock-keyword-face)
    ;; keywords
    (,(rx-to-string '(: bow (| "@" "!") (| alpha "_") (* (| alnum "_")) eow))
     . font-lock-function-name-face)
    ;; algorithm meta-specifiers
    (,(rx-to-string '(: bow (| "__" "$") (| "display" "write" "unsigned" "signed" "widthof" "sameas") eow))
     . font-lock-builtin-face)
    ;; intrinsics
    (,(rx-to-string '(: bow (? "u") "int" (* digit) eow))
     . font-lock-type-face)
    ;; builtin types
    (,(rx-to-string '(: (+ digit) (| "b" "B" "h" "H" "d" "D") (+ xdigit) eow))
     . font-lock-constant-face)
    (,(rx-to-string '(: bow (+ digit) eow))
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
