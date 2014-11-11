Hammock
=======

A partial implementation of [Clojure][] in pure Ruby.

**Warning**: this software is alpha quality and bugridden. Production
usage is not recommended.

Why?
----

Not for speed, that's for sure.

Originally, I started this project to make a version of Clojure that
was fast enough to use a scripting language. As more and more of the
`clojure.core` namespace was implemented, though, it became clear that a
fast bootstrap was not going to happen using pure Ruby.

I've continued to implement much of `clojure.core`, though, to see how
far I could take the project. It turns out, you can get pretty far.
The experience has certainly leveled me up in Ruby, but I've learned a
ton about Clojure's internals. In fact, even if no one ever uses this
library, I will still consider it a success. **If you've never implemented
a Lisp before, I highly recommend it.** And Ruby's flexibility lends
itself to exploring this kind of thing.

Features
--------

* Persistent immutable data structures (leveraging [hamster][])
    - List
    - Vector
    - Map
    - Set
* Metadata
* Multimethods
* Lazy sequences
* Transducers
* Ruby iterop
* Multiple-arity functions
* Macros
* Atomic reference types (Var and Atom)
* watches (for Atoms)
* function composition, paritialling
* Namespaces, and require/refer
* destructuring binding forms
* try/catch/finally using Ruby exceptions


Planned Features
----------------

* Queue
* Transients
* Protocols, and reify
* tag-literals (data readers)
* defrecord
* Better printing support
* sorted collections
* sort
* read, eval, print (the functions themselves)
* Ruby Array/Hash interop via aset, aget, etc
* peek/pop
* functions for regular expressions
* List comprehension (via for)
* promise/deliver
* multimethod "prefer"
* spit/slurp
* Lots of clojure.core functions that haven't been implemented for various reasons


Probably never, or not applicable in Ruby
-----------------------------------------

* defstruct
* import
* agents, refs, STM
* thread, future, pmap (because of Ruby's GIL)
* deftype and friends (definterface, proxy, genclass)
* Inlinable functions
* Type hints
* unchecked math
* monitors/locking
* annotations


[Clojure]: http://clojure.org
[hamster]: http://github.com/hamstergem/hamster
