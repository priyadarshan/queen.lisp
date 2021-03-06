(in-package #:queen)

(defmethod parse-pgn ((in stream))
  (with-parse-stream in
    (labels
        ((read-sym ()
           (read-while #'alnum?))

         (read-header ()
           (let (name value)
             (skip #\[)
             (setf name (read-sym))
             (skip-whitespace)
             (setf value (read-string))
             (skip #\])
             (cons name value)))

         (read-result ()
           (if (eql #\* (peek))
               (progn (next) "*")
               (look-ahead 3 (lambda (chars)
                               (unless (member nil chars)
                                 (let ((str (coerce chars 'string)))
                                   (cond
                                     ((string= "1-0" str)
                                      "1-0")
                                     ((string= "0-1" str)
                                      "0-1")
                                     ((string= "1/2" str)
                                      (skip "-1/2")
                                      "1/2-1/2"))))))))

         (read-moves (game)
           (let ((data '()))
             (flet ((move ()
                      (let* ((movestr (read-while #'non-whitespace?))
                             (valid (game-parse-san game movestr)))
                        (skip-whitespace)
                        (cond
                          ((null valid)
                           (error "Invalid move (~A)" movestr))
                          ((< 1 (length valid))
                           (error "Ambiguous move (~A)" movestr)))
                        (game-move game (car valid))
                        (push (cons :move (car valid)) data)))
                    (comment1 ()
                      (skip #\;)
                      (read-while (lambda (ch)
                                    (not (eql #\Newline ch)))))
                    (comment2 ()
                      (skip #\{)
                      (prog1
                          (read-while (lambda (ch)
                                        (not (eql #\} ch))))
                        (skip #\}))))
               (loop while (peek)
                     do (skip-whitespace)
                        (or (awhen (read-result)
                              (push (cons :result it) data)
                              (return (nreverse data)))
                            (when (eql (peek) #\;)
                              (push (cons :comment (comment1)) data))
                            (when (eql (peek) #\{)
                              (push (cons :comment (comment2)) data))
                            (progn
                              (when (read-number)
                                (skip #\.)
                                (when (eql #\. (peek))
                                  (skip ".."))
                                (skip-whitespace))
                              (move)))
                        (skip-whitespace)
                     finally (return (nreverse data)))))))

      (skip-whitespace)
      (let* ((headers (loop while (eql #\[ (peek))
                            collect (prog1 (read-header)
                                      (skip-whitespace))))
             (game (make-instance 'game))
             (start-fen (assoc "fen" headers :test #'string-equal)))
        (reset-from-fen game (if start-fen
                                 (cdr start-fen)
                                 +FEN-START+))
        `(:headers ,headers
          :moves ,(read-moves game)
          :game ,game)))))

(defmethod parse-pgn ((pgn string))
  (with-input-from-string (in pgn)
    (parse-pgn in)))
