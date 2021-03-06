(in-package :windxow)

(progno  (def-key-callback key-callback (window key scancode action mod-keys)
	     (declare (ignorable scancode window))
	     (let* ((key-state (key key))
		    (mod-shift (ash mod-keys +mod-key-shift+))
		    (new (next-key-state key-state action))
		    (new-composite (logior mod-shift new)))
	       (declare (type fixnum mod-shift new new-composite))
	       (setf (key key) new-composite)))
	   (def-mouse-button-callback mouse-callback (window button action mod-keys)
	     (declare (ignorable window))
	     (let* ((key-state (mice button))
		    (mod-shift (ash mod-keys +mod-key-shift+))
		    (new (next-key-state key-state action))
		    (new-composite (logior mod-shift new)))
	       (declare (type fixnum mod-shift new new-composite))
	       (setf (mice button) new-composite)))
	   (def-char-callback char-callback (window char)
	     (declare (ignorable window))
	     (vector-push-extend (code-char char) *chars*)))

(progno
;;;when buttons can take either of two states, there are four
;;;ways adjacent time frames can look [repeat does not count here]
 (defun next-key-state (old new)
   (cond ((eq nil old)
	  (if (eql new +press+) +press+))
	 ((eq +true+ old)
	  (cond ((eql new +release+) +release+)
		((eql new +repeat+) +repeat+))))))
