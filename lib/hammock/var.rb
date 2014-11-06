require 'atomic'
require 'hammock/ideref'
require 'hammock/errors'
require 'hammock/map'

module Hammock
  class Var
    include Meta
    include IFn
    Undefined = Object.new

    BINDING_KEY = "__bindings__".freeze

    class Frame
      attr_reader :bindings, :prev
      def initialize(bindings, prev)
        @bindings, @prev = bindings, prev
      end
      TOP = new(Map.new, nil)
    end

    def self.dvals
      Thread.current[BINDING_KEY] ||= Frame::TOP
    end

    def self.dvals=(vals)
      Thread.current[BINDING_KEY] = vals
    end

    def self.thread_bindings
      f = dvals
      ret = Map.new
      f.bindings.each do |k,v|
        ret.assoc(k, v)
      end
      ret
    end

    def self.push_thread_bindings(bindings)
      f = dvals
      bmap = f.bindings
      bindings.each do |v,val|
        if !v.dynamic?
          raise Error, "Can't dynamically bind non-dynamic var: #{v.inspect}"
        end
        v.thread_bound!
        bmap = bmap.assoc(v, val)
      end
      self.dvals = Frame.new(bmap, f)
    end

    def self.pop_thread_bindings
      f = dvals.prev
      if f.nil?
        raise Error, "Pop without matching push"
      else
        self.dvals = f
      end
    end

    def self.intern(ns_name, sym, val=Undefined)
      if Namespace === ns_name
        ns = ns_name
      else
        ns = Namespace.find_or_create(ns_name)
      end

      var = ns.intern(sym)
      var.bind_root(val) unless val == Undefined
      var
    end

    def self.find(ns_qualified_sym)
      unless ns = ns_qualified_sym.ns
        raise Error, "Symbol must be namespace-qualified"
      end
      unless namespace = Namespace.find(ns)
        raise Error, "No such namespace: #{ns}"
      end
      namespace.find_var(ns_qualified_sym.name)
    end

    attr_reader :ns, :symbol, :root

    def initialize(*args)
      if args.length > 1
        @ns, @symbol, @root = args
      else
        @root = args.first
      end

      @meta = nil
      @dynamic = false
      @public = true
      @thread_bound = Atomic.new(false)
      @rev = 0
    end

    alias namespace ns

    def trace
      return unless meta
      "#{meta[:file]}:#{meta[:line]} in #@symbol"
    end

    def macro!
      @meta = meta.assoc :macro, true
    end

    def dynamic!
      @dynamic = true
      self
    end

    def thread_bound!
      @thread_bound.value = true
    end

    def thread_bound?
      @thread_bound.value
    end

    def thread_binding
      if thread_bound?
        self.class.dvals.bindings[self]
      end
    end

    def bound?
      root? || (thread_bound? && self.class.dval.bindings.key?(self))
    end

    def root?
      @rev > 0
    end

    def dynamic?
      @dynamic
    end

    def public?
      @public
    end

    def private?
      !@public
    end

    def deref
      thread_binding || @root
    end

    def bind_root(val)
      @rev += 1
      @root = val
    end

    def unbind_root
      @root = nil
    end

    def meta=(meta)
      if meta[:private]
        @public = false
      end
      if meta[:dynamic]
        @dynamic = true
      end
      @meta = meta
    end

    def call(*args)
      @root.call(*args)
    end

    def to_s
      if @ns
        "#'#{@ns.name}/#{symbol.name}"
      else
        n = symbol ? symbol.to_s : "--unnamed--"
        "#<Var: #{n}>"
      end
    end
    alias inspect to_s
  end
end
