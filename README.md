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

Usage
-----

$ hammock path/to/file.clj

OR

$ hammock --repl

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
* functions for regular expressions
* Ruby Array/Hash interop via aset, aget, etc
* Namespaces, and require/refer
* destructuring binding forms
* Chunked sequences
* try/catch/finally using Ruby exceptions


Planned Features
----------------

* Transients
* Protocols, and reify
* tag-literals (data readers)
* defrecord
* Better printing support (via protocols)
* sorted collections
* read, print (the functions themselves)
* peek/pop
* List comprehension (via for)
* Queue
* promise/deliver
* multimethod "prefer"
* letfn
* spit/slurp


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

License
-------

This project is not endorsed by Rich Hickey, but this project contains
code based on his work. Such code is licensed under the following
license

    Copyright (c) Rich Hickey. All rights reserved.
    The use and distribution terms for this software are covered by the
    Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
    which can be found in the file epl-v10.html at the root of this distribution.
    By using this software in any fashion, you are agreeing to be bound by
    the terms of this license.
    You must not remove this notice, or any other, from this software.

The rest of this code also resides under the Eclipse Public License 1.0
(same as Clojure).


[Clojure]: http://clojure.org
[hamster]: http://github.com/hamstergem/hamster
