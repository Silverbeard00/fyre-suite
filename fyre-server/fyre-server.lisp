;;;; fyre-server.lisp

(in-package #:fyre-server)

(defmacro standard-page (&body body)
  `(with-html-output-to-string
       (*standard-output*  nil :prologue t :indent t)
     (:html :lang "en"
	    (:body
	     ,@body))))

(defmacro standard-item ((&key id) &body body)
  `(with-html-output
       (*standard-output* nil :indent t)
     (:div :id ,id :value ,@body)))

(define-easy-handler (image-test :uri "/image-test") ()
    (with-html-output-to-string
	(*standard-output* nil :prologue t :indent t)
      (:html :lang "en"
	     (:body
	      (:img :src "test.jpg")))))

(define-easy-handler (fyre-list :uri "/fyre-list") ()
  (standard-page (easy-list-data (all-fyre-names))))

(define-easy-handler (fyre-add :uri "/fyre-add") (data)
  (if (fyre-with-name data)
      (format nil "No dice hombre")
      (progn
	(make-instance 'fyre :name data :ttl 600)
	(format nil "Added ~a to Fyres" data))))

(define-easy-handler (ember-list :uri "/ember-list") (fyre)
  (if (fyre-with-name fyre)
      (standard-page (easy-list-data (mapcar #'store-object-id
					     (ember-with-parent fyre))))
      (format nil "No embers with that parent")))

(define-easy-handler (ember-add :uri "/ember-add") (fyre ember)
  (if (and (not (ember-with-name ember)) (fyre-with-name fyre))
      (progn
	(make-instance 'ember :name ember :fyre-parent fyre)
	(format nil "Added ~a to ~a Fyre" ember fyre))
      (format nil "Error adding ember")))

(define-easy-handler (get-id :uri "/getid") ()
  (let ((inte (parse-integer (get-parameter "value"))))
    (standard-page (easy-id-values (store-object-with-id inte)))))

(define-easy-handler (spark-list :uri "/spark-list") (ember)
  (if (not (null ember))
      (standard-page
	(easy-list-data
	 (mapcar #'store-object-id
		 (all-ember-sparks (ember-id ember)))))
      (format nil "No sparks for that buddy")))

(define-easy-handler (spark-add :uri "/spark-add") (ember spark)
  (if (and ember spark)
      (progn
	(make-instance 'spark
		       :ember-parent (ember-id ember)
		       :content spark
		       :picture ""
		       :user "")
	(format nil "Spark added to Ember"))
      (format nil "Invalid Spark Request")))

(defun fyre-start (port)
  (start (make-instance 'easy-acceptor :port port
			:document-root #p"/home/silver/quicklisp/local-projects/fyre-server/")))

(define-persistent-class fyre ()
  ((name :read
	 :index-initargs (:test #'equal)
	 :index-type hash-index
	 :index-reader fyre-with-name
	 :index-values all-fyres)
   (ttl  :read
	 :index-initargs (:test #'equal)
	 :index-type hash-index
	 :index-reader fyre-with-ttl
	 :index-values all-fyre-ttl)))

(define-persistent-class ember ()
  ((name :read
	 :index-type hash-index
	 :index-reader ember-with-name
	 :index-initargs (:test #'equal)
	 :index-values all-embers)
   (fyre-parent :read
		:index-type hash-index
		:index-reader ember-with-parent
		:index-initargs (:test #'equal)
		:index-values all-parents)))

(define-persistent-class spark ()
   ((ember-parent
    :read
    :index-type hash-index
    :index-reader spark-with-name
    :index-initargs (:test #'equal)
    :index-values all-sparks)
    (content :update)
    (picture :update)
    (user :read
	  :index-type string-unique-index
	  :index-reader sparks-with-user
	  :index-values all-users)))
   
	
(define-persistent-class media (blob)
  ((name :read)))

(defun load-store ()
  (make-instance 'mp-store
		 :directory "~/quicklisp/local-projects/fyre-server/fyre-pit/"
		 :subsystems
		 (list (make-instance 'store-object-subsystem)
		       (make-instance 'blob-subsystem))))

(defun all-fyre-names ()
    (mapcar #'(lambda (e) (fyre-name e)) (all-fyres)))

(defun ember-id (ember)
  (let ((res (car (ember-with-name ember))))
    (if res
	(store-object-id res)
	nil)))

(defun all-ember-sparks (e-id)
  (spark-with-name e-id))

(defun easy-list-data (data)
  (let ((len (length data)))
    (mapcar #'(lambda (x e) (standard-item (:id e) x))
	    data (alexandria:iota len))))

(defun easy-id-values (obj)
  (let ((typ (type-of obj)))
    (cond
      ((equal typ 'ember)
       (easy-ember-values obj))
      ((equal typ 'fyre)
       (easy-fyre-values obj))
      ((equal typ 'spark)
       (easy-spark-values obj))
      (t
       '()))))

(defun easy-ember-values (obj)
  (with-slots (name) obj
    (with-html-output
	 (*standard-output* nil :indent t)
       (:htm
	(:div :id "obj-type"  :value "ember")
	(:div :id "ember-name" :value name)))))

(defun easy-fyre-values (obj)
  (with-slots (name) obj
    (with-html-output
	 (*standard-output* nil :indent t)
       (:div :id "obj-type" :value "fyre")
       (:div :id "fyre-name" :value name))))

(defun easy-spark-values (obj)
  (with-slots (content) obj
      (with-html-output
	   (*standard-output* nil :indent t)
	 (:div :id "obj-type" :value "spark")
	 (:div :id "spark-content" :value content)
	 (:div :id "spark-picture" :value "")
	 (:div :id "spark-user" :value ""))))

