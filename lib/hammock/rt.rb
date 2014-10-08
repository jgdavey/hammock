require 'atomic'
require 'pathname'
require 'hammock/reader'
require 'hammock/namespace'
require 'hammock/environment'
require 'hammock/loop_locals'
require 'hammock/recur_locals'
require 'hammock/cons_cell'
require 'hammock/var'
require 'hammock/vector'
require 'hammock/function'
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
      ConsCell.from_array(args)
    end

    def self.global_env
      @global_env = Hammock::Environment.new(
        "*ns*" => CURRENT_NS,
        "*in*" => IN,
        "*out*" => OUT,
        "*err*" => ERR
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
        form.evaluate(global_env)
      end
    ensure
      file.close
    end

    def self.specials
      @specials ||= {
        "def"   => Def.new,
        "if"    => If.new,
        "let*"  => Let.new,
        "do*"   => Do.new,
        "fn*"   => Fn.new,
        "loop*" => Loop.new,
        "recur" => Recur.new,
        "in-ns" => InNS.new,
        "."     => Host.new,
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
      sequence.cons(val)
    end

    def self.conj(sequence, val)
      sequence.conj(val)
    end

    def self.first(sequence)
      if coll = seq(sequence)
        coll.car
      end
    end

    def self.next(sequence)
      if coll = seq(sequence)
        coll.cdr
      end
    end

    def self.more(sequence)
      if coll = seq(sequence)
        coll.cdr || ConsCell.new(nil, nil)
      end
    end

    def self.seq(sequence)
      case sequence
      when ConsCell
        sequence
      else
        if sequence.respond_to?(:to_a)
          ConsCell.from_array sequence.to_a
        end
      end
    end

    class InNS
      def call(_, env, form)
        ns = Namespace.find_or_create(form.evaluate(env))
        CURRENT_NS.bind_root(ns)
      end
    end

    class Def
      def call(_, env, sym, val)
        ns = CURRENT_NS.deref
        ns.intern(sym).tap do |var|
          var.bind_root(val.evaluate(env))
          var.meta = sym.meta
        end
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

        arities = bodies.map do |body|
          bindings, *body = *body
          unless Vector === bindings
            raise "Function declarations must begin with a binding form"
          end
          Function::Arity.new(bindings, *body)
        end

        Function.create(name, CURRENT_NS.deref, env, arities).tap do |fn|
          fn.meta = list.meta
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
          ret = catch(:recur) do
            env = env.merge(locals)
            ret = nil
            b = body.to_a
            until b.empty?
              ret = b.first.evaluate(env)
              b.shift
            end
            ret
          end

          if RecurLocals === ret
            locals = locals.rebind(ret)
          else
            break ret
          end
        end
      end
    end

    class Recur
      def call(_, env, *args)
        args = args.map {|arg| arg.evaluate(env)}
        throw(:recur, RecurLocals.new(args))
      end
    end

    class Host
      def call(_, env, target, *args)
        method = args.first
        arguments = []

        if ConsCell === args.first
          method, *arguments = *args.first
          arguments = arguments.map {|arg| arg.evaluate(env)}
        end
        target.evaluate(env).send(method.name, *arguments)
      end
    end

    class VarExpr
      def call(list, env, sym)
        namespace = env["__namespace__"] || sym.ns || CURRENT_NS.deref
        namespace.has_var?(sym.name) && namespace.find_var(sym.name)
      end
    end
  end
end
