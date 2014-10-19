require 'hammock/ideref'

module Hammock
  class Volatile
    include IDeref

    def initialize(val)
      @value = val
    end

    def deref
      @value
    end

    def reset(newval)
      @value = newval
    end
  end
end
