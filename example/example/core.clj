(ns example.core)

(defn fizzbuzz-upto
  [n]
  (filter (fn [x]
            (or
              (zero? (mod x 5))
              (zero? (mod x 3))))
          (range 1 n)))

(defn fizzbuzz-sum-below
  [n]
  (apply + (fizzbuzz-upto n)))
