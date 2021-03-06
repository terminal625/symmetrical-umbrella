(in-package :sandbox)


(defparameter *mouse-rectangle* (vector 0.0 0.0 0.0 0.0))
(defparameter *cursor-rectangle* (vector 0.0 0.0 0.0 0.0))
(progn
  (progn
    (defparameter *old-mouse-x* 0.0)
    (defparameter *old-mouse-y* 0.0))
  (progn
    (defparameter *mouse-x* 0.0)
    (defparameter *mouse-y* 0.0)))

(progn
  (defparameter *camera-x* 0)
  (defparameter *camera-y* 0))

(defparameter *chunks* (pix:make-world))
(defparameter *chunk-call-lists* (make-eq-hash))

(defparameter *cam-rectangle* (vector 0 0 0 0))

(defparameter *ticks* 0)

(defparameter *running* nil)

(defun physics ()
  (incf *ticks*)
  (etouq
   (with-vec-params (vec-slots :rectangle
			       (quote ((x0 :x0)
				       (y1 :y1)
				       (x1 :x1)
				       (y0 :y0))))
     (quote (*mouse-rectangle*))
;;     (quote (declare (type single-float x0 y1 x1 y0)))
     (quote (progn
	      (setf
	       x0 x1
	       y0 y1)
	      (multiple-value-bind (x y) (window:get-mouse-position)
		(setf x1 (- (+ x x) *window-width*)
		      y1 (+ (- (+ y y)) *window-height*)))
	      (etouq
	       (with-vec-params (vec-slots :rectangle
					   (quote ((cx0 :x0)
						   (cy1 :y1)
						   (cx1 :x1)
						   (cy0 :y0))))
		 (quote (*cursor-rectangle* symbol-macrolet))
		 (quote (setf cx0 (floor x0 *block-width*)
			      cy0 (floor y0 *block-height*)
			      cx1 (floor x1 *block-width*)
			      cy1 (floor y1 *block-height*)))))
	      (etouq
	       (with-vec-params (vec-slots :rectangle
					   (quote ((rx0 :x0)
						   (ry1 :y1)
						   (rx1 :x1)
						   (ry0 :y0))))
		 (quote (*mouse-rectangle* symbol-macrolet))
		 (quote (setf rx0 x0
			      ry0 y0
			      rx1 x1
			      ry1 y1))))))))
  (when (skey-j-p :escape)
    (setf e:*status* t))
  (progn *running*
      (when (zerop (mod *ticks* (floor (/ 60 60))))
	(other-stuff))
      (etouq
       (with-vec-params (vec-slots :rectangle
				   (quote ((cx0 :x0)
					   (cy1 :y1)
					   (cx1 :x1)
					   (cy0 :y0))))
	 (quote (*cursor-rectangle*))
	 (quote
	  (when (smice-p :left)
	    (decf *camera-x* (- cx1 cx0))
	    (decf *camera-y* (- cy1 cy0)))))))

  (centered-rectangle *cam-rectangle* *camera-x* *camera-y*
		      (/ e:*width* *block-width*) (/ e:*height* *block-height*)))


(defun centered-rectangle (rect x y width height)
  (etouq
   (with-vec-params (vec-slots :rectangle
			       (quote ((x0 :x0)
				       (y1 :y1)
				       (x1 :x1)
				       (y0 :y0))))
     (quote (rect symbol-macrolet))
     (quote
      (setf
       x0 (- x width)
       y0 (- y height)
       x1 (+ x width)
       y1 (+ y height))))))

(defun set-char-with-update (x y value world)
  (multiple-value-bind (chunk offset) (pix::area x y world)
    (setf (aref chunk offset) value)
    (setf (aref chunk (* 16 16)) *ticks*)))

(defun chunk-update (x y world)
  (multiple-value-bind (chunk offset) (pix::area x y world)
    (setf (aref chunk (* 16 16)) *ticks*)))

(defun (setf get-char) (value x y world)
  (set-char value x y world))

(defun get-char (x y world)
  (multiple-value-bind (chunk offset) (pix::area x y world)
    (aref chunk offset)))

 (defun set-char (value x y world)
  (multiple-value-bind (chunk offset) (pix::area x y world)
    (setf (aref chunk offset) value)))


(progn
  (declaim (ftype (function (t) fixnum) get-char-num))
  (with-unsafe-speed
    (defun get-char-num (obj)
      (typecase obj
	(fixnum obj)
	(cons (get-char-num (car obj)))
	(character (logior *white-black-color* (char-code obj)))
	(t (sxhash obj))))))

(defun print-page (x y)
  (let ((array (gethash (pix:xy-index x y)
			sandbox::*chunks*)))
    (if array
	(let ((fin (make-array (+ 16 (* 16 16)) :element-type 'character)))
	  (let ((counter 0))
	    (dotimes (y 16)
	      (progn (setf (aref fin counter) #\Newline)
		     (incf counter))
	      (dotimes (x 16)
		(let ((value (aref array (+ x (ash y 4)))))
		  (setf (aref fin counter)
			(if value
			    (code-char (mod (get-char-num value) 256))
			    #\Space)))
		(incf counter))))
	  fin))))

(progn
  (declaim (ftype (function (fixnum fixnum t fixnum)
			    (values fixnum fixnum))
		  copy-string-to-world))
  (defun copy-string-to-world (x y string color)
    (let ((start x))
      (let ((len (length string)))
	(dotimes (index len)
	  (let ((char (aref string index)))
	    (cond ((char= char #\Newline)
		   (setf x start y (1- y)))
		  (t
		   (set-char-with-update x y
					 (logior (char-code char) color)
					 *chunks*)
		   (setf x (1+ x))))))
	(values x y)))))

(defun scwu (char x y)
  (set-char-with-update x
			y
			char
			*chunks*))

(defun keyword-ascii (keyword &optional (value (gethash keyword e:*keypress-hash*)))
  (when value
    (let ((code (gethash keyword *keyword-ascii*)))
      (when code
	(let ((mods (ash value (- e::+mod-key-shift+))))
	  (multiple-value-bind (char esc) (convert-char code mods)
	    (values char esc)))))))


(defparameter node nil)

(defparameter directions (alexandria:circular-list :up :left :down :right))
(defun other-stuff ()
  (let ((moved? nil)
	(last-node node)) 
    (progno
     (with-hash-table-iterator (next e:*keypress-hash*)
       (loop (multiple-value-bind (more key value) (next)
	       (if more
		   (let ((ans (keyword-ascii key value)))
		     (whEn ans
		       (when (e::r-or-p (e::get-press-value value))
			 (setf moved? t)
			 (node-splice
			  (node-left node)
			  (vector-circular-node
			   (string (code-char ans)))))))
		   (return))))))
 
    (when (skey-r-or-p :up)
      (block nil
	(setf node (or (node-up node)
		       (return)))
	(setf moved? t)))
    (when (skey-r-or-p :down)
      (block nil
	(setf node (or (node-down node)
		       (return)))
	(setf moved? t)))
    (cond ((skey-p :right-control)
	     ;;;long jumps
	   (when (skey-r-or-p :s)
	     (block nil
	       (setf node (or (node-left (jump-car node))
			      (node-left node)
			      (return)))
	       (setf moved? t)))
	   (when (skey-r-or-p :f)
	     (block nil
	       (setf node (or (node-right (jump-cdr node))
			      (node-right node)
			      (return)))
	       (setf moved? t))))
	  ((or (skey-p :right-alt)
	       (skey-p :left-alt))
	   ;;character
	   (when (skey-r-or-p :s)
	     (block nil
	       (setf node (or (prev-newline node)
			      (return)))
	       (setf moved? t)))
	   (when (skey-r-or-p :f)
	     (block nil
	       (setf node (or (next-newline node)
			      (return)))
	       (setf moved? t))))
	  ((skey-p :left-shift)
	   (progn
	     (when (skey-r-or-p :s)
	       (block nil
		 (setf node (or (node-left node)
				(return)))
		 (setf moved? t)))
	     (when (skey-r-or-p :f)
	       (block nil
		 (setf node (or (node-right node)
				(return)))
		 (setf moved? t)))))
	  (t
	     ;;;cons cells
	     ;;;left moves to previous car
	     ;;;right moves to next cdr
	   (when (skey-r-or-p :s)
	     (block nil
	       (setf node (or 
			   (labels ((find-car (node &optional (count 256))
				      (when node
					(unless (zerop count)					  
					  (let ((payload (node-payload (node-up node))))
					    (let ((type (car (car payload))))
					      (if (and (eq type (quote car))
						   ;    (atom (car (cdr payload)))
						       )
						  node						  
						  (let ((car (jump-car node)))
						    (if (and (atom (cdr (node-payload (node-up car))))
							     (eq (quote cdr) type))	       
							car
							(find-car (node-left node) (1- count)))))))))))
			     (find-car (if (eq (quote car)
					       (car (car (node-payload (node-up node)))))
					   (node-left node)
					   node)))
			   (return)))
	       (setf moved? t)))
	   (when (skey-r-or-p :f)
	     (block nil
	       (setf node (or 
			   (labels ((find-cdr (node &optional (count 256))
				      (when node
					(unless (zerop count)
					  (let ((payload (node-payload (node-up node))))
					    (let ((type (car (car payload))))
					      (if (and (eq (quote cdr) type)
						    ;   (atom (car (cdr payload)))
						       )
						node
						(if (and (atom (cdr payload))
							 (eq (quote car) type))
						    (jump-cdr node)
						    (find-cdr (node-right node) (1- count))))))))))
			     (find-cdr (if (eq (quote cdr)
					       (car (car (node-payload (node-up node)))))
					   (node-right node)
					   node)))
			   (return)))
	       (setf moved? t)))))
    (progn (when (skey-r-or-p :d)
	     (block nil
	       (setf node (or (short-down node)
			      (next-newline node nil)
			      (return)))
	       (setf moved? t)))
	   (when (skey-r-or-p :e)
	     (block nil
	       (setf node (or (short-up node)
			      (prev-newline node nil)
			      (return)))
	       (setf moved? t))))

    (when (skey-r-or-p :kp-4)
      (setf moved? t)
      (let ((payload (node-payload node)))
	(let ((newline (cdr payload)))
	  (when Newline
	    (decf (cdr payload))
	    (width-prop (node-right node) -1)))))
    (when (skey-r-or-p :kp-6)
      (setf moved? t)
      (let ((payload (node-payload node)))
	(let ((newline (cdr payload)))
	  (when Newline
	    (incf (cdr payload))
	    (width-prop (node-right node) 1)))))

    (when (skey-r-or-p :kp-5)
      (setf moved? t)
      (let ((payload (node-payload node)))
	(let ((newline (cdr payload)))
	  (if Newline
	      (progn
		(setf (cdr payload) nil)
		(width-prop (node-right node) (- Newline))) 
	      (setf (cdr payload) 0)))))

    (when (skey-r-or-p :backspace)
      (setf moved? t)
      (let ((ans (node-left node)))
	(node-disconnect ans)))
    (when (skey-r-or-p :j)
      (print (node-payload (node-up node)))
      (print (node-payload node)))
    (when (skey-p :l)
      (dobox ((x 0 228)
	      (y 0 70))
	     (scwu (random most-positive-fixnum) x y)))
    (when (or t (skey-p :o))
      (progn
	(let ((width *window-block-width*)
	      (height *window-block-height*))
	  (let ((xstart *camera-x*)
		(ystart *camera-y*))
	    (let ((b (get-stuff :glyph-screen *other-stuff* *backup*)))
	      (dobox ((xpos 0 *window-block-width*)
		      (ypos 0 *window-block-height*))		   
		     (let ((offset (* 4 (+ xpos (* ypos width))))
			   (value (get-char (+ xpos xstart) (+ ypos ystart) *chunks*)))
		       (let ((num (get-char-num value)))
			 (progn
			   (setf (cffi:mem-aref b :uint8 (+ offset 0)) (logand 255 num))
			   (setf (cffi:mem-aref b :uint8 (+ offset 1)) (ldb (byte 8 8) num))
			   (setf (cffi:mem-aref b :uint8 (+ offset 2)) (ldb (byte 8 40) num))
			   ))))
	      (progn
		(gl:bind-texture :texture-2d (get-stuff :text-scratch *stuff* *backup*))
		(gl:tex-sub-image-2d :texture-2d 0 0 0 width height :rgba :unsigned-byte b)))))))
    (progn
      (when (skey-r-or-p :kp-enter)
	(setf moved? t)
	(setf node (turn-node node))
	(pop directions)
	(copy-string-to-world 0 5 (symbol-name (car directions)) *white-black-color*)))
    (when moved?
;      (clear-screen)
      (unless (eq node last-node)
	(setf (car (node-payload node))
	      (let ((char (car (node-payload node))))
		(if (typep char (quote character))
		    (setf char (char-code char)))
		(typecase char
		  (fixnum (let (( a (logand 255 char)))
			    (logior a (random-color)))))))
	(setf (car (node-payload last-node))
	      (let ((char (car (node-payload last-node))))
		(if (typep char (quote character))
		    (setf char (char-code char)))
		(typecase char
		  (fixnum (let ((a (logand 255 char)))
			    (logior a *white-black-color*)))))))
      (draw-nodal-text *node-start* 0 0 1 -1 nil 1024)
      (draw-nodal-text (reverse-node *node-start*) 0 0 1 -1 t 1024))))

(defparameter *uint-lookup*
  (let ((ans (make-array (length *16x16-tilemap*) :element-type '(unsigned-byte 8))))
    (map-into ans (lambda (x) (round (* x 255))) *16x16-tilemap*)))

(defun prev-newline (node &optional (after t))
  (labels ((rec (lastnode node &optional (cap 1024))
	     (if node
		 (unless (zerop cap)
		   (let ((newline (cdr (node-payload node))))
		     (if (typep newline (quote fixnum))
			 (if after lastnode node)
			 (rec node
			      (node-left node)
			      (1- cap)))))
		 lastnode)))
    (rec (node-left node)
	 (node-left (node-left node)))))

(defun next-newline (node &optional (before t))
  (labels ((rec (lastnode node &optional (cap 1024))
	     (if node
		 (unless (zerop cap)
		   (let ((newline (cdr (node-payload node))))
		     (if (typep newline (quote fixnum))
			 (if before node lastnode)
			 (rec node
			      (node-right node)
			      (1- cap)))))
		 lastnode)))
    (rec (node-right node)
	 (node-right (node-right node)))))

(defun short-down (node &optional (cap 1024))
  (labels ((node-newline (node)
	     (let ((newline (cdr (node-payload node))))
	       (if (typep newline (quote fixnum))
		   Newline
		   0)))
	   (rec (node offset)
	     (when node
	       (unless (zerop cap)
		 (decf cap) 
		 (if (zerop offset)
		     node
		     (rec (node-right node)
			  (1+ (+ offset (node-newline node)))))))))
    (rec (node-right node) (1+ (node-newline node)))))

(defun short-up (node &optional (cap 1024))
  (labels ((node-newline (node)
	     (let ((newline (cdr (node-payload node))))
	       (if (typep newline (quote fixnum))
		   newline
		   0)))
	   (rec (node offset)
	     (when node
	       (unless (zerop cap)
		 (decf cap)
		 (decf offset (node-newline node))
		 (if (zerop offset)
		     node
		     (rec (node-left node) (1- offset)))))))
    (let ((left-node (node-left node)))
      (rec left-node -1))))

(defun jump-cdr (node)
  (node-down (node-right (node-up node))))
(defun jump-car (node)
  (node-down (node-left (node-up node))))

(defun random-color ()
  (logandc1 255 (random most-positive-fixnum)))

(defun color-invert (color)
  (logior (logand 255 color)
	  (logand (logxor most-positive-fixnum 255)
		  (lognot color))))

(defun draw-nodal-text (node x y dx dy reversep &optional (count 32))
  (block nil
    (flet ((draw-forward ()
	     (dotimes (counter count)
	       (unless node
		 (return))
	       (let ((payload (node-payload node)))
		 (scwu node x y)
		 (let ((linefeed (cdr payload)))
		   (when (typep linefeed 'fixnum)
		     (incf x linefeed)
		     (incf y dy)))
		 (pop node))
	       (incf x dx)))
	   (draw-backwards ()
	     (dotimes (counter count)
	       (unless node
		 (return))
	       (let ((payload (node-payload node)))
		 (unless (zerop counter)
		   (let ((linefeed (cdr payload)))
		     (when (typep linefeed 'fixnum)
		       (decf x linefeed)
		       (decf y dy))))
		 (scwu node x y)
		 (pop node))
	       (decf x dx))))
      (if reversep
	  (draw-backwards)
	  (draw-forward)))))

(defun clear-screen (&optional (rect *cam-rectangle*))
  (etouq
   (with-vec-params (vec-slots :rectangle
			       (quote ((x0 :x0)
				       (y1 :y1)
				       (x1 :x1)
				       (y0 :y0))))
     (quote (rect let))
     (quote
      (progn
	(dobox ((x (floor x0) (ceiling x1))
		(y (floor y0) (ceiling y1)))
	       (scwu nil x y)))))))

(setf *print-case* :downcase)

(defparameter *cell-character-buffer* (make-array 0
					:adjustable t
					:fill-pointer 0
					:element-type 'character))

(defun print-cells2 (form &optional (chars *cell-character-buffer*))
  (let* ((start (make-cons-node #\())
	 (end start)
	 (counter 0))
    (labels ((attach-char-node (node)
	       (node-connect-right end node)
	       (setf end node)
	       (incf counter))
	     (attach-char-and-place (char node)
	       (let ((new-node (make-cons-node char)))
		 (node-connect-up new-node node)
		 (attach-char-node new-node)
		 new-node))
	     (prin1-and-done (object parent-node)
	       (setf (fill-pointer chars) 0)
	       (with-output-to-string (stream chars)
		 (prin1 object stream))
	       (let ((len (fill-pointer chars)))
		 (let ((first-node (make-cons-node (aref chars 0))))
		   (node-connect-up first-node parent-node)
		   (attach-char-node first-node)
		   (dobox ((index 1 len))
			  (attach-char-node
			   (make-cons-node (aref chars index)))))))
	     (rec (sexp)
	       (let ((cdr (cdr sexp))
		     (car (car sexp)))
		 (let ((rightcar (cons (quote car) nil))
		       (leftcar (cons (quote cdr) nil)))
		   (let ((cell-car-node (make-cons-node rightcar sexp))
			 (cell-cdr-node (make-cons-node leftcar sexp)))
		     (node-connect-right cell-car-node cell-cdr-node)
		     (let ((old-len counter))
		       (if (listp car)
			   (if car
			       (progn
				 (attach-char-and-place #\( cell-car-node)
				 (rec car))
			       (prin1-and-done nil cell-car-node))
			   (prin1-and-done car cell-car-node))
		       (let ((width (1+ (- counter old-len))))
			 (setf (cdr rightcar) width
			       (cdr leftcar) width))
		       (if (listp cdr)
			   (if cdr
			       (progn
				 (attach-char-and-place #\Space cell-cdr-node)
				 (rec cdr))
			       (attach-char-and-place #\) cell-cdr-node))
			   (progn ;;;dotted list?
			     (error "fuck you")
			     (princ " . ")
			     (prin1  cdr)
			     (princ ")")))))))))
      (rec form))
    (values start end)))

(defun setwidth (node width)
  (let ((other (node-left node)))
    (unless other
      (setf other (node-right node)))
    (setf (cdr (car (node-payload other))) width
	  (cdr (car (node-payload node))) width)))

(defun width-prop (node width)
  (unless (zerop width)
    (when node
      (let ((top (node-up node))) 
	(let ((payload (node-payload top)))
	  (let ((type (car payload)))
	    (case (car type)
	      (car (let ((cdr-end (jump-cdr node)))
		     (let ((payload (node-payload cdr-end)))
		       (let ((newline (cdr payload)))
			 (if (typep newline 'fixnum)
			     (decf (cdr payload) width)
			     (width-prop (node-right cdr-end) width))))))
	      (cdr (setwidth top (+ (cdr type) width))
		   (let ((payload (node-payload node)))
		     (let ((newline (cdr payload)))
		       (if (typep newline 'fixnum)
			   (decf (cdr payload) width)
			   (width-prop (node-right node) width)))))
	      (otherwise
	       (let ((payload (node-payload node)))
		 (let ((newline (cdr payload)))
		   (if (typep newline 'fixnum)
		       (decf (cdr payload) width)
		       (width-prop (node-right node) width))))))))))))

(defparameter *test-tree*
  (copy-tree
   (quote
    (defun print-cells (sexp)
      (let ((cdr (cdr sexp))
	    (car (car sexp)))
	(if (listp car)
	    (if car
		(progn
		  (princ "(")
		  (print-cells car))
		(princ nil))
	    (prin1 car))
	(if (listp cdr)
	    (if cdr
		(progn
		  (princ " ")
		  (print-cells cdr))
		(princ ")"))
	    (progn
	      (princ " . ")
	      (prin1  cdr)
	      (princ ")"))))))))

(defparameter *node-start* nil)
(defun reset-test ()
  (setf node (print-cells2 *test-tree*))
  (setf *node-start* (reverse-node (last (reverse-node node))))
  (quote reset-test))


(defun reload-test ()
  (setf *chunks* (aload "indentation")
	*node-start* (reverse-node (get-char 0 0 *chunks*))
	node *node-start*)
  (quote nil))

(defun color-rgb (color)
  (labels ((c (r g b)
	     (values (/ r 255.0) (/ g 255.0) (/ b 255.0)))
	   (c6 (x)
	     (let ((b (mod x 6))
		   (g (mod (floor x 6) 6))
		   (r (mod (floor x 36) 6)))
	       (values (/ r 5.0) (/ g 5.0) (/ b 5.0))))
	   (g (x)
	     (let ((gray (/ x 23.0)))
	       (values gray gray gray))))
    (case color
      (0 (c 0 0 0))
      (1 (c 205 0 0))
      (2 (c 0 205 0))
      (3 (c 205 205 0))
      (4 (c 0 0 238))
      (5 (c 205 0 205))
      (6 (c 0 205 205))
      (7 (c 229 229 229))
      (8 (c 127 127 127))
      (9 (c 255 0 0))
      (10 (c 0 255 0))
      (11 (c 255 255 0))
      (12 (c 92 92 255))
      (13 (c 255 0 255))
      (14 (c 0 255 255))
      (15 (c 255 255 255))
      (t (let ((c (- color 16)))
	   (if (< c 216)
	       (c6 c)
	       (g (- c 216))))))))

