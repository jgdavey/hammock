require 'hammock/meta'
require 'hammock/ifn'

module Hammock
  class Function
    include Meta
    include IFn

    attr_reader :arities
    attr_writer :meta

    def self.alloc_from(fn, meta)
      new(fn.internal_name, fn.ns, fn.env, fn.arities).tap do |fn|
        fn.meta = meta
      end
    end

    def self.create(name, ns, env, arities)
      new(name, ns, env, arities)
    end

    def initialize(internal_name, ns, env, arities)
      @internal_name = internal_name || generate_name
      @ns = ns
      @env = env
      @arities = arities
      @meta = nil
    end

    def variadic?
      arities.any?(&:variadic?)
    end

    def arity_counts
      arities.map(&:arity)
    end

    def find_arity!(*args)
      needed = args.to_a.length
      arities.detect {|a| a.handles_arity?(needed)} or \
        raise ArgumentError, wrong_arity_message(needed)
    end

    def wrong_arity_message(needed)
      c = arity_counts.map(&:to_s)
      c << "more" if variadic?
      if c.length == 1
        counts = c.first
      else
        counts = c[0..-2].join(", ") + " or #{c.last}"
      end
      "Wrong number of args passed to #{name}. Expected #{counts}; Got #{needed}"
    end

    def name
      "#{ns.name}/#@internal_name"
    end

    def meta=(meta)
      @meta = meta
    end

    def trace
      return unless meta
      "#{meta[:file]}:#{meta[:line]} in #@internal_name"
    end

    def call(*args)
      arity = find_arity!(*args)

      env = @env.bind("__namespace__", @ns)
      env = env.bind(@internal_name, self)

      locals = args

      loop do
        env = arity.bind_env(env, locals.to_a)
        ret = nil
        body = arity.body.dup
        until body.empty?
          ret = body.first.evaluate(env)
          body.shift
        end
        if RecurLocals === ret
          if ret.to_a.last.nil?
            locals = ret.to_a[0..-2]
          else
            locals = ret
          end
        else
          break ret
        end
      end
    end

    def inspect
      "#<Hammock::Function #@internal_name>"
    end

    protected

    attr_reader :ns, :env, :internal_name

    private

    def generate_name
      "fn__#{RT.next_id}"
    end

    class Arity
      AMPERSAND = Symbol.intern("&")

      attr_reader :bindings, :body, :arity, :args

      def initialize(bindings, *body)
        @bindings, @body = bindings, body
        @locals, @args, @variadic, @variadic_name = unpack_args(bindings)
        @arity = @args.length
      end

      def bind_env(env, args)
        max = variadic? ? @args.length - 1 : @args.length

        0.upto(max) do |i|
          env = env.bind @args[i], args[i]
        end

        if variadic?
          lastarg = nil
          if args.length > max
            tail = args[max..-1]
            lastarg = Sequence.from_array(tail) if tail && !tail.empty?
          end
          env = env.bind @variadic_name, lastarg
        end

        env
      end

      def handles_arity?(count)
        if variadic?
          count >= @arity - 1
        else
          count == @arity
        end
      end

      def variadic?
        @variadic
      end

      def unpack_args(form)
        locals = {}
        args = []
        lastisargs = false
        argsname = nil

        form.each do |x|
          if x == AMPERSAND
            lastisargs = true
            next
          end
          if lastisargs and argsname
            raise "variable length argument must be the last in the function #{form.inspect}"
          end
          argsname = x.name if lastisargs
          if !(Symbol === x) || x.ns
            raise "fn* arguments must be non namespaced symbols, got #{x}: in #{form.inspect}"
          end
          locals[x] = RT.list(x)
          args << x.name
        end

        return locals, args, lastisargs, argsname
      end
    end
  end
end
