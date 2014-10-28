require 'atomic'
require 'pry'
require 'pathname'
require 'hammock/reader'
require 'hammock/namespace'
require 'hammock/environment'
require 'hammock/loop_locals'
require 'hammock/recur_locals'
require 'hammock/stream'
require 'hammock/reduced'
require 'hammock/sequence'
require 'hammock/lazy_sequence'
require 'hammock/lazy_transformer'
require 'hammock/var'
require 'hammock/vector'
require 'hammock/function'
require 'hammock/volatile'
require 'hammock/core_ext'

module Hammock
  class RT
    CLOJURE_NS = Namespace.find_or_create(Symbol.intern("clojure.core"))
    CURRENT_NS = Var.intern(CLOJURE_NS, Symbol.intern("*ns*"), CLOJURE_NS).dynamic!
    OUT = Var.intern(CLOJURE_NS, Symbol.intern("*out*"), $stdout).dynamic!
    IN = Var.intern(CLOJURE_NS, Symbol.intern("*in*"), $stdin).dynamic!
    ERR = Var.intern(CLOJURE_NS, Symbol.intern("*err*"), $stderr).dynamic!
    LOADPATH = Var.intern(CLOJURE_NS, Symbol.intern("*load-path*"),
                          Hammock::Vector.from_array($LOAD_PATH)).dynamic!
    ID = Atomic.new(0)


    def self.next_id
      ID.update {|v| v + 1}
    end

    def self.var(*args)
      sym = Symbol.intern(*args)
      unless ns = Namespace.find(sym.ns)
        raise ArgumentError, "must provide an existing namespace to intern a var"
      end
      ns.find_var!(sym.name)
    end

    def self.list(*args)
      Sequence.from_array(args)
    end

    def self.global_env
      @global_env = Hammock::Environment.new(
        "__stack__" => Vector.new.add("(root)"),
        "*ns*" => CURRENT_NS,
        "*in*" => IN,
        "*out*" => OUT,
        "*err*" => ERR,
        "RT" => self,
        "Map" => Map,
        "Vector" => Vector,
        "Set" => Hammock::Set,
        "Symbol" => Hammock::Symbol,
        "Keyword" => ::Symbol,
        "Sequence" => Sequence,
        "Meta" => Meta
      )
    end

    def self.bootstrap!
      return if @bootstrapped
      Hammock::RT.require("clojure/core.clj")
      @bootstrapped = true
    end

    def self.resolve_path(path)
      return path if ::Pathname === path
      pathname = nil
      LOADPATH.deref.each do |dir|
        pn = Pathname.new File.join(dir, path)
        if pn.exist?
          pathname = pn
          break
        end
      end
      pathname
    end

    def self.require(path)
      if pathname = resolve_path(path)
        load_resource(pathname)
      else
        raise "Cannot resolve file #{path}"
      end
    end

    def self.load_resource(file)
      unless file.respond_to?(:getc)
        file = File.open(file)
      end
      Reader.new.read_all(file) do |form|
        Compiler.compile(global_env, form).evaluate(global_env)
      end
    ensure
      file.close
    end

    def self.specials
      @specials ||= {
        "def"   => Def.new,
        "if"    => If.new,
        "let*"  => Let.new,
        "do"    => Do.new,
        "fn*"   => Fn.new,
        "loop*" => Loop.new,
        "recur" => Recur.new,
        "throw" => Throw.new,
        "in-ns" => InNS.new,
        "list"  => List.new,
        "."     => Host.new,
        "quote" => QuoteExpr.new,
        "var"   => VarExpr.new
      }
    end

    def self.special(name_or_sym)
      if Symbol === name_or_sym
        name = name_or_sym.name
      else
        name = name_or_sym
      end
      specials[name]
    end

    def self.cons(val, sequence)
      case sequence
      when Hammock::List, LazyTransformer
        sequence.cons(val)
      else
        if s = seq(sequence)
          s.cons(val)
        else
          Sequence.new(val)
        end
      end
    end

    def self.conj(sequence, val)
      sequence.conj(val)
    end

    def self.assoc(sequence, key, val)
      if sequence
        sequence.assoc(key, val)
      end
    end

    def self.dissoc(sequence, key)
      if sequence
        sequence.dissoc(key)
      end
    end

    def self.get(sequence, key, not_found=nil)
      if sequence
        sequence.val_at(key, not_found)
      end
    end

    def self.contains?(sequence, key)
      case sequence
      when Vector
        sequence.count > key
      when Map, Set
        sequence.has_key?(key)
      end
    end

    def self.first(sequence)
      if coll = seq(sequence)
        coll.first
      end
    end

    def self.second(sequence)
      if coll = seq(sequence)
        if coll = coll.tail
          coll.first unless coll.empty?
        end
      end
    end

    def self.next(sequence)
      if coll = seq(sequence)
        t = coll.tail
        t unless t.empty?
      end
    end

    def self.more(sequence)
      if coll = seq(sequence)
        coll.tail
      else
        EmptyList.new
      end
    end

    def self.seq(sequence)
      case sequence
      when NilClass
        nil
      when Hammock::List, LazyTransformer, LazySequence, Map, Hammock::Set, Vector
        sequence.seq
      else
        if sequence.respond_to?(:to_a)
          list = Sequence.from_array sequence.to_a
          list unless list.empty?
        end
      end
    end

    def self.iter(coll)
      if coll.respond_to?(:each)
        coll.to_enum
      else
        seq(coll).to_enum
      end
    end

    def self.seq?(sequence)
      Hammock::List === sequence
    end

    def self.reduced?(obj)
      Hammock::Reduced === obj
    end

    def self.count(sequence)
      if sequence
        sequence.count
      else
        0
      end
    end

    def self.nth(sequence, *args)
      case sequence
      when String
        key = args.first
        sequence[key,1] if key < sequence
      when Hammock::List
        sequence.nth(*args)
      else
        sequence.fetch(*args)
      end
    end

    def self.equal(a, b)
      a == b
    end

    def self.subvec(vector, start_idx, end_idx)
      Vector::SubVector.new(vector.meta, vector, start_idx, end_idx)
    end

    def self.divide(num1, num2)
      if (num1 % num2).zero?
        num1 / num2
      else
        num1.quo(num2)
      end
    end

    def self.make_keyword(*args)
      return args.first if ::Symbol === args.first
      if args.length == 1
        *ns, name = args.first.to_s.split("/", 2)
        parts = [ns.first, name].compact
      else
        parts = args[0..1]
      end
      parts.join("/").to_sym
    end

    class InNS
      def call(_, env, form)
        ns = Namespace.find_or_create(form.evaluate(env))
        CURRENT_NS.bind_root(ns)
      end
    end

    class Def
      def call(_, env, sym, val=nil)
        ns = CURRENT_NS.deref
        var = ns.find_var(sym) || ns.intern(sym)
        var.bind_root(val.evaluate(env))
        var.meta = sym.meta
        var
      end
    end

    class If
      def call(_, env, predicate, then_clause, else_clause=nil)
        if predicate.evaluate(env)
          then_clause.evaluate(env)
        else
          else_clause.evaluate(env)
        end
      end
    end

    class Do
      def call(_, env, *body)
        ret = nil
        b = body.to_a
        until b.empty?
          ret = b.first.evaluate(env)
          b.shift
        end
        ret
      end
    end

    class Let
      def call(_, env, bindings, *body)
        unless bindings.count.even?
          raise "Odd number of binding forms passed to let"
        end

        bindings.to_a.each_slice(2) do |k, v|
          env = env.bind(k.name, v.evaluate(env))
        end

        Do.new.call(_, env, *body)
      end
    end

    class Fn
      def call(list, env, *args)
        if Symbol === args.first
          name = args.first.name
          args.shift
        else
          name = nil
        end

        bodies = args

        if Vector === RT.first(bodies)
          bodies = RT.list(bodies)
        end

        arities = bodies.to_a.map do |body|
          bindings, *body = *body
          unless Vector === bindings
            raise "Function declarations must begin with a binding form"
          end
          Function::Arity.new(bindings, *body)
        end

        Function.create(name, CURRENT_NS.deref, env, arities).tap do |fn|
          fn.meta = list.meta if list.meta
        end
      end
    end

    class Loop
      def call(form, env, bindings, *body)
        if body.length < 1
          raise ArgumentError, "loop* takes at least two args"
        end

        unless Vector === bindings
          raise ArgumentError, "loop* takes a vector as it's first argument"
        end

        if bindings && (bindings.length % 2 != 0)
          raise ArgumentError, "loop* takes a even number of bindings"
        end

        locals = LoopLocals.empty

        bindings.to_a.each_slice(2) do |k, v|
          locals = locals.bind(k.name, v.evaluate(env))
        end

        loop do
          env = env.merge(locals)
          ret = nil
          b = body.to_a.dup
          until b.empty?
            ret = b.first.evaluate(env)
            b.shift
          end
          ret

          if RecurLocals === ret
            locals = locals.rebind(ret)
          else
            break ret
          end
        end
      end
    end

    class List
      def call(form, env, *args)
        if Vector === args.last
          *first, last = *args
          args = first + last.to_a
        end
        Sequence.from_array(args.to_a.map {|arg| arg.evaluate(env)})
      end
    end

    class Recur
      def call(_, env, *args)
        args = args.to_a.map {|arg| arg.evaluate(env)}
        RecurLocals.new(args)
      end
    end

    class Throw
      def call(form, env, message_or_error)
        raise message_or_error.evaluate(env)
      end
    end

    class Host
      def call(_, env, target, *args)
        method = args.first
        arguments = []

        if Sequence === args.first
          method, *arguments = *args.first
          arguments = arguments.to_a.map {|arg| arg.evaluate(env)}
        end
        target.evaluate(env).send(method.name, *arguments)
      end
    end

    class VarExpr
      def call(list, env, sym)
        namespace = env["__namespace__"] || sym.ns || CURRENT_NS.deref
        if namespace.has_var?(sym.name)
          namespace.find_var(sym.name)
        else
          raise "Unable to find var #{sym} in namespace #{namespace.name}"
        end
      end
    end

    class QuoteExpr
      def call(list, env, form)
        form
      end
    end
  end
end
