module Hammock
  class Function
    AMPERSAND = Symbol.intern("&")

    attr_reader :body, :args

    def self.create(*args)
      new(*args)
    end

    def initialize(internal_name, ns, env, args, *body)
      @internal_name = internal_name
      @ns = ns
      @env = env
      @orig_args = args
      @locals, @args, @variadic, @variadic_name = unpack_args(args)
      @body = body
    end

    def source
      body
    end

    def variadic?
      @variadic
    end

    def call(form, env, *args)
      apply(*args)
    end

    def validate_arity(*args)
      if variadic?
        args.to_a.length >= @args.to_a.length - 1 or raise \
          "Wrong number of arguments passed to #{@internal_name || 'function'}:" \
          " need #{@args.to_a.length - 1} or more args, got #{args.to_a.length}"
      else
        args.to_a.length == @args.to_a.length or raise \
          "Wrong number of arguments passed to #{@internal_name || 'function'}:" \
          " #{args.to_a.length} for #{@args.to_a.length}"
      end
    end

    def apply(*args)
      validate_arity(*args)

      env = @env.bind("__namespace__", @ns)

      max = variadic? ? @args.length - 1 : @args.length

      0.upto(max) do |i|
        env = env.bind @args[i], args[i]
      end

      if variadic?
        lastarg = ConsCell.from_array(args[max..-1])
        env = env.bind @variadic_name, lastarg
      end

      body.reduce(nil) do |ret, form|
        form.evaluate(env)
      end
    end

    private

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
