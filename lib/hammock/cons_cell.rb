module Hammock
  class ConsCell
    include Enumerable

    def self.from_array(array)
      array.reverse.inject(nil) do |prev, el|
        new(el, prev)
      end
    end

    attr_reader :car, :cdr

    def initialize(car, cdr)
      @car, @cdr = car, cdr
    end

    def ==(other)
      return false unless other.respond_to?(:car)
      car == other.car && cdr == other.cdr
    end

    def next?
      not cdr.nil?
    end

    def cons(item)
      self.class.new(item, self)
    end

    def each
      cell = self
      loop do
        yield cell.car
        break unless cell.next?
        cell = cell.cdr
      end
      self
    end

    def inspect
      "(#{self.map(&:inspect).join(' ')})"
    end
  end
end
