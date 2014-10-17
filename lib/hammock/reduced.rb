module Hammock
  class Reduced
    def initialize(value)
      @value = value
    end

    def deref
      @value
    end
  end
end
