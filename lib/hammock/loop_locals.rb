require 'hammock/map'
require 'hammock/vector'

module Hammock
  class LoopLocals
    def self.empty
      new([], [])
    end

    def initialize(names, bindings)
      unless Hammock::Map === bindings
        bindings = Hammock::Map.new bindings
      end
      unless Hammock::Vector === names
        names = Hammock::Vector.from_array(names)
      end
      @bindings = bindings
      @names = names
    end

    def frame
      @bindings
    end

    def rebind(recur_locals)
      bindings = Hammock::Map.from_array @names.to_a.zip(recur_locals.to_a).flatten(1)
      self.class.new(@names, bindings)
    end

    def bind(name, val)
      self.class.new(@names.cons(name), @bindings.assoc(name, val))
    end
  end
end
