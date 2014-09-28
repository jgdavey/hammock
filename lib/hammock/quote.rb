module Hammock
  class Quote
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      return false unless Quote === other
      other.value == @value
    end

    def evaluate(_)
      @value
    end
  end
end
