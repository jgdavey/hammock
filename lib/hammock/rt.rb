require 'pathname'
require 'hammock/reader'
require 'hammock/namespace'
require 'hammock/environment'
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
        "in-ns" => InNS.new,
        "."     => Host.new
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

    class InNS
      def call(env, form)
        ns = Namespace.find_or_create(form.evaluate(env))
        CURRENT_NS.bind_root(ns)
      end
    end

    class Def
      def call(env, sym, val)
        ns = CURRENT_NS.deref
        ns.intern(sym).tap do |var|
          var.bind_root(val.evaluate(env))
          var.meta = sym.meta
        end
      end
    end

    class If
      def call(env, predicate, then_clause, else_clause)
        if predicate.evaluate(env)
          then_clause.evaluate(env)
        else
          else_clause.evaluate(env)
        end
      end
    end

    class Do
      def call(env, *body)
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
      def call(env, bindings, *body)
        unless bindings.count.even?
          raise "Odd number of binding forms passed to let"
        end

        bindings.to_a.each_slice(2) do |k, v|
          env = env.bind(k.name, v.evaluate(env))
        end

        Do.new.call(env, *body)
      end
    end

    class Fn
      def call(env, *args)
        if Symbol === args.first
          internal_name = args.first.name
          args.shift
        else
          internal_name = nil
        end

        bindings, *body = args
        unless Vector === bindings
          raise "Function declarations must begin with a binding form"
        end

        Function.create(internal_name, CURRENT_NS.deref, env, bindings, *body)
      end
    end

    class Host
      def call(env, target, *args)
        method = args.first
        arguments = []

        if ConsCell === args.first
          method, *arguments = *args.first
          arguments = arguments.map {|arg| arg.evaluate(env)}
        end
        target.evaluate(env).send(method.name, *arguments)
      end
    end
  end
end
