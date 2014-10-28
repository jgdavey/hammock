require 'hammock/map'
require 'hammock/ifn'
require 'hammock/errors'

module Hammock
  class MultiMethod
    include IFn
    attr_reader :method_table

    def initialize(name, dispatch_fn, default_dispatch)
      @name = name.to_s
      @dispatch_fn = dispatch_fn
      @default_dispatch = default_dispatch
      @method_table = Map.new
      @lock = Mutex.new
    end

    def reset
      @lock.synchronize do
        @method_table = Map.new
      end
      self
    end

    def add_method(dispatch_value, fn)
      @lock.synchronize do
        @method_table = method_table.assoc(dispatch_value, fn)
      end
      self
    end

    def remove_method(dispatch_value)
      @lock.synchronize do
        @method_table = method_table.without(dispatch_value)
      end
      self
    end

    def get_method(dispatch_val)
      @method_table.get(dispatch_val) || @method_table.get(@default_dispatch)
    end

    def call(*args)
      dval = @dispatch_fn.call(*args)
      if fn = get_method(dval)
        fn.call(*args)
      else
        raise Error, "No method in multimethod #@name for dispatch value: #{dval}"
      end
    end
  end
end
