(ns example
  (:require [example.core :as core]))

(defn -main [& args]
  (let [upto (first args)]
    (if upto
      (println (core/fizzbuzz-sum-below (int upto)))
      (println "ERROR: please provide an argument"))))
