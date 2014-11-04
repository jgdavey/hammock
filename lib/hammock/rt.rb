require 'atomic'
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
require 'hammock/multi_method'
require 'hammock/atom'
require 'hammock/volatile'
require 'hammock/chunked_cons'
require 'hammock/chunk_buffer'
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
        "RT" => self,
        "Map" => Map,
        "Vector" => Vector,
        "Set" => Hammock::Set,
        "Symbol" => Hammock::Symbol,
        "Keyword" => ::Symbol,
        "Var" => Hammock::Var,
        "Atom" => Hammock::Atom,
        "List" => Hammock::List,
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
      if File.extname(path).empty?
        path += ".clj"
      end
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
      return_to_ns = CURRENT_NS.deref
      unless file.respond_to?(:getc)
        file = File.open(file)
      end
      Reader.new.read_all(file) do |form|
        compile_and_eval(form)
      end
    ensure
      file.close
      CURRENT_NS.bind_root(return_to_ns)
    end

    def self.compile_and_eval(form)
      Compiler.compile(global_env, form).evaluate(global_env)
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
        "var"   => VarExpr.new,
        "try"   => Try.new
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
      when LazyTransformer, LazySequence
        sequence.seq
      when ISeq
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

    def self.keys(sequence)
      sequence.keys if sequence
    end

    def self.vals(sequence)
      sequence.vals if sequence
    end

    def self.count(sequence)
      case sequence
      when NilClass
        0
      when String
        sequence.length
      else
        sequence.count
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
      if end_idx < start_idx || start_idx < 0 || end_idx > vector.count
        raise IndexError
      end

      if start_idx == end_idx # empty
        Vector.new
      else
        Vector::SubVector.new(vector.meta, vector, start_idx, end_idx)
      end
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

    def self.splat_last(target, method, *args)
      *first, last = *args
      target.send(method, *first, *last)
    end

    def self.find(coll, key)
      if Map === coll
        coll.entry_at(key)
      end
    end

    class InNS
      def call(_, env, form)
        ns = Namespace.find_or_create(form.evaluate(env))
        CURRENT_NS.bind_root(ns)
      end
    end

    class Def
      Undefined = Object.new

      def call(_, env, sym, val=Undefined)
        ns = CURRENT_NS.deref
        var = ns.find_var(sym) || ns.intern(sym)
        var.bind_root(val.evaluate(env)) unless val == Undefined
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

        ns = env["__namespace__"] || CURRENT_NS.deref
        Function.create(name, ns, env, arities).tap do |fn|
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

    class Try
      CATCH = Symbol.intern("catch")
      FINALLY = Symbol.intern("finally")
      def call(form, env, *exprs)
        exp = exprs.reverse
        catches = []
        finally = nil

        loop do
          expr = exp.first
          if Hammock::List === expr
            if !finally && expr.first == FINALLY && catches.empty?
              _, *body = *expr
              finally = Finally.new(*body)
              exp.shift
            elsif expr.first == CATCH
              _, classname, name, *body = *expr
              catches << Catch.new(classname.evaluate(env), name, *body)
              exp.shift
            else
              break
            end
          else
            break
          end
        end

        exprs = exp.reverse
        catches.reverse!

        begin
          Do.new.call(nil, env, *exprs)
        rescue Exception => e
          if c = catches.detect {|c| c.handles?(e)}
            env = env.bind(c.local.name, e)
            return c.evaluate(env)
          else
            raise e
          end
        ensure
          finally.evaluate(env)
        end
      end

      class Finally
        def initialize(*body)
          @body = body
        end
        def evaluate(env)
          Do.new.call(nil, env, *@body)
        end
      end

      class Catch
        attr_reader :local
        def initialize(errorclass, local, *body)
          @errorclass = errorclass
          @local = local
          @body = body
        end

        def handles?(error)
          @errorclass === error
        end

        def evaluate(env)
          Do.new.call(nil, env, *@body)
        end
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
