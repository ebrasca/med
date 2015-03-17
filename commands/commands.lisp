(in-package :med)

;;;; Begin command wrappers.

;;; Motion & mark commands.

(defun forward-char-command ()
  (move-char (current-buffer *editor*)))

(defun backward-char-command ()
  (move-char (current-buffer *editor*) -1))

(defun next-line-command ()
  (move-line (current-buffer *editor*)))

(defun previous-line-command ()
  (move-line (current-buffer *editor*) -1))

(defun forward-word-command ()
  (move-word (current-buffer *editor*)))

(defun backward-word-command ()
  (move-word (current-buffer *editor*) -1))

(defun forward-sexp-command ()
  (move-sexp (current-buffer *editor*)))

(defun backward-sexp-command ()
  (move-sexp (current-buffer *editor*) -1))

(defun move-beginning-of-line-command ()
  (move-beginning-of-line (current-buffer *editor*)))

(defun move-end-of-line-command ()
  (move-end-of-line (current-buffer *editor*)))

(defun move-beginning-of-buffer-command ()
  (move-beginning-of-buffer (current-buffer *editor*)))

(defun move-end-of-buffer-command ()
  (move-end-of-buffer (current-buffer *editor*)))

(defun set-mark-command ()
  (set-mark (current-buffer *editor*)))

(defun exchange-point-and-mark-command ()
  (exchange-point-and-mark (current-buffer *editor*)))

;;; Editing commands.

(defun self-insert-command ()
  (insert (current-buffer *editor*) *this-character*))

(defun quoted-insert-command ()
  (insert (current-buffer *editor*) (editor-read-char)))

(defun delete-forward-char-command ()
  (delete-char (current-buffer *editor*)))

(defun delete-backward-char-command ()
  (delete-char (current-buffer *editor*) -1))

(defun kill-line-command ()
  (kill-line (current-buffer *editor*)))

(defun kill-region-command ()
  (let ((buffer (current-buffer *editor*)))
    (kill-region buffer (buffer-point buffer) (buffer-mark buffer))))

(defun copy-region-command ()
  (let ((buffer (current-buffer *editor*)))
    (copy-region buffer (buffer-point buffer) (buffer-mark buffer))))

(defun kill-sexp-command ()
  (let* ((buffer (current-buffer *editor*))
         (point (buffer-point buffer)))
    (with-mark (current point)
      (move-sexp buffer 1)
      (kill-region buffer current point))))

(defun forward-kill-word-command ()
  (let* ((buffer (current-buffer *editor*))
         (point (buffer-point buffer)))
    (with-mark (current point)
      (move-word buffer 1)
      (kill-region buffer current point))))

(defun backward-kill-word-command ()
  (let* ((buffer (current-buffer *editor*))
         (point (buffer-point buffer)))
    (with-mark (current point)
      (move-word buffer -1)
      (kill-region buffer current point))))

(defun yank-command ()
  (yank-region (current-buffer *editor*)))

;;; Display commands.

(defun recenter-command ()
  (recenter (current-buffer *editor*)))

(defun redraw-screen-command ()
  (redraw-screen))

(defun scroll-up-command ()
  ;; Find the display line at the bottom of the screen and recenter on that.
  (let ((current-screen (editor-current-screen *editor*))
        (point (buffer-point (current-buffer *editor*))))
    (dotimes (i (length current-screen))
      (let ((line (aref current-screen (- (length current-screen) i 1))))
        (when line
          (setf (mark-line point) (display-line-line line)
                (mark-charpos point) (display-line-start line))
          (recenter (current-buffer *editor*))
          (return))))))

(defun scroll-down-command ()
  ;; Recenter on the topmost display line.
  (let* ((current-screen (editor-current-screen *editor*))
         (line (aref current-screen 0))
         (point (buffer-point (current-buffer *editor*))))
    (setf (mark-line point) (display-line-line line)
          (mark-charpos point) (display-line-start line))
    (recenter (current-buffer *editor*))))

;;; Other commands.

(defun keyboard-quit-command ()
  (error "Keyboard quit."))

(defun list-buffers-command ()
  (let ((buffer (get-buffer-create "*Buffers*")))
    (setf (last-buffer *editor*) (current-buffer *editor*))    
    (switch-to-buffer buffer)
    ;; Clear the whole buffer.
    (delete-region buffer
                   (make-mark (first-line buffer) 0)
                   (make-mark (last-line buffer) (line-length (last-line buffer))))
    (dolist (b (buffer-list))
      (insert buffer (buffer-property b 'name))
      (insert buffer #\Newline))
    (setf (buffer-modified buffer) nil)))

(defun buffer-completer (text)
  (let (results)
    (push text results)
    (dolist (buffer *buffer-list*)
      (when (search text (buffer-property buffer 'name))
        (push (buffer-property buffer 'name) results)))
    results))

(defun switch-to-buffer-command ()
  (let* ((default-buffer (or (last-buffer *editor*)
                             (current-buffer *editor*)))
         (name (string-trim " " (read-from-minibuffer (format nil "Buffer (default ~A): " (buffer-property default-buffer 'name)) :completer #'buffer-completer)))
         (other-buffer (if (zerop (length name))
                           default-buffer
                           (get-buffer-create name))))
    (when (not (eql (current-buffer *editor*) other-buffer))
      (setf (last-buffer *editor*) (current-buffer *editor*))
      (switch-to-buffer other-buffer))))

(defun kill-buffer-command ()
  (let* ((name (read-from-minibuffer (format nil "Buffer (default ~A): " (buffer-property (current-buffer *editor*) 'name))))
         (buffer (if (zerop (length name))
                     (current-buffer *editor*)
                     (or (get-buffer name)
                         (error "No buffer named ~S" name)))))
    (when (buffer-modified buffer)
      (when (not (minibuffer-yes-or-no-p "Buffer ~S modified, kill anyway?" (buffer-property buffer 'name)))
        (return-from kill-buffer-command)))
    (kill-buffer buffer)))

(defun get-buffer-create (name)
  (setf name (string name))
  (or (get-buffer name)
      (let ((buffer (make-instance 'buffer)))
        (setf (buffer-property buffer 'name) name)
        (push buffer (buffer-list))
        buffer)))

(defun get-buffer (name)
  (dolist (b (buffer-list))
    (when (string-equal (buffer-property b 'name) name)
      (return b))))

(defun kill-buffer (buffer)
  (setf (buffer-list) (remove buffer (buffer-list)))
  (when (eql buffer (last-buffer *editor*))
    (setf (last-buffer *editor*) nil))
  (when (eql buffer (current-buffer *editor*))
    (switch-to-buffer
     (if (buffer-list)
         (first (buffer-list))
         (get-buffer-create "*Scratch*")))
    (when (>= (length (buffer-list)) 2)
       (setf (last-buffer *editor*) (second (buffer-list))))))

(defun unique-name (name &optional version)
  (let ((actual-name (if version
                         (format nil "~A <~D>" name version)
                         name)))
    (if (get-buffer actual-name)
        (unique-name name (if version
                              (1+ version)
                              1))
        actual-name)))

(defun rename-buffer (buffer new-name)
  (unless (string-equal (buffer-property buffer 'name) new-name)
    (setf (buffer-property buffer 'name) (unique-name new-name))
    (refresh-title)))

;;; Lisp commands.

(defun beginning-of-top-level-form (buffer)
  "Move to the start of a top-level form.
A top-level form is designated by an open parenthesis at the start of a line."
  (let ((point (buffer-point buffer)))
    (setf (mark-charpos point) 0)
    (loop
       (when (eql (character-right-of point) #\()
         (return))
       (when (not (previous-line (mark-line point)))
         (error "Can't find start of top-level form."))
       (setf (mark-line point) (previous-line (mark-line point))))))

(defun symbol-at-point (buffer)
  (save-excursion (buffer)
    (move-sexp buffer 1)
    (with-mark (point (buffer-point buffer))
      (move-sexp buffer -1)
      (buffer-string buffer point (buffer-point buffer)))))

(defun newline-command ()
  (insert (current-buffer *editor*) #\Newline))

(defun open-line-command ()
  (let ((buffer (current-buffer *editor*)))
    (move-end-of-line buffer)
    (newline-command)))

(defun eval-last-sexp-command ()
   (let* ((buffer (current-buffer *editor*)))
     (with-mark (point (buffer-point buffer))
       (save-excursion (buffer)
         (move-sexp buffer -1)
         (let ((string (buffer-string buffer point (buffer-point buffer))))
           (print (eval (read-from-string string))))))))

(defun find-matching-paren-command ()
  "Jump the cursor the paren that matches the one under the cursor."
  ;; FIXME: skip parens in strings
  (with-mark (point (buffer-point (current-buffer *editor*)))
    (let* ((buffer (current-buffer *editor*))
           (c (line-character (mark-line point) (mark-charpos point))))
        (when (char= c #\))
           (beginning-of-top-level-form buffer)
           (let ((string (buffer-string buffer point (buffer-point buffer)))
                 (count 1))
             (do ((i (1- (length string)) (decf i)))
                 ((< i 0))
                (unless (and (> i 1) (and (char= (char string (1- i)) #\\)
                                          (char= (char string (- i 2)) #\#)))
                  (case (char string i)
                    (#\( (decf count))
                    (#\) (incf count))))
              (when (zerop count)
                (move-mark (buffer-point buffer) i)
                (return)))))
         (when (char= c #\()
           (beginning-of-top-level-form buffer)
           (move-sexp buffer)
           (let ((string (buffer-string buffer point (buffer-point buffer)))
                 (count 0))
             (do ((i 0 (incf i)))
                 ((= i (length string)))
                (unless (and (> i 1) (and (char= (char string (1- i)) #\\)
                                          (char= (char string (- i 2)) #\#)))
                  (case (char string i)
                    (#\( (incf count))
                    (#\) (decf count))))
                (when (zerop count)
                  (move-mark (buffer-point buffer) (- (length string)))
                  (move-mark (buffer-point buffer) i)
                  (return))))))))

(defun find-symbol-at-point-command ()
  (let* ((buffer (current-buffer *editor*))
         (symbol (symbol-at-point buffer)))
    (loop 
      (move-sexp buffer 1)
      (search-forward buffer symbol)
      (move-sexp buffer -1)
      (when (string= (symbol-at-point buffer) symbol)
          (return)))))

(defun execute-extended-command ()
  (let ((command (concatenate 'string "(med::" (read-from-minibuffer "M-x ") "-command)")))
    (format t "Executing extended command: ~A~%" command)
    (eval (read-from-string command))))

(defun new-frame-command ()
  (spawn))

(defun repl-command ()
  (start-repl))

(defun grep-command ()
  (grep))

(defun cd-command ()
  (let* ((buffer (current-buffer *editor*))
         (dir (read-from-minibuffer "Directory: " 
                                    :default (namestring 
                                               (buffer-property buffer 
                                                               'default-pathname-defaults)))))
    (setf (buffer-property buffer 'default-pathname-defaults) (pathname dir))))

(defun compile-buffer-command ()
  (save-buffer-command)
  (mezzano.supervisor::make-thread
    (lambda () (cal (buffer-property (current-buffer *editor*) 'path)))
    :name "compile-file"
    :initial-bindings `((*editor* ,*editor*) 
                        (*standard-output* ,*standard-output*))))