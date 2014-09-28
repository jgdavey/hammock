module Hammock
  class Function
    attr_reader :body, :bindings

    def initialize(internal_name, ns, env, bindings, *body)
      @internal_name = internal_name
      @ns = ns
      @env = env
      @bindings = bindings
      @body = body
    end

    def source
      body
    end

    def call(env, *args)
      apply(*args)
    end

    def apply(*args)
      unless args.to_a.length == bindings.to_a.length
        raise "Wrong number of arguments passed to #{@internal_name || 'function'}:" \
          " #{args.to_a.length} for #{bindings.to_a.length}"
      end

      env = @env.bind("__namespace__", @ns)

      bindings.to_a.zip(args) do |sym, val|
        env = env.bind(sym.name, val)
      end

      body.reduce(nil) do |ret, form|
        form.evaluate(env)
      end
    end
  end
end
