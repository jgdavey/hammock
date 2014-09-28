require 'hammock/list_evaluator'

module Hammock
  class ConsCell
    include Meta
    include Enumerable

    def self.from_array(array)
      array.reverse.inject(nil) do |prev, el|
        new(el, prev)
      end
    end

    def self.alloc_from(other, meta=nil)
      new(other.car, other.cdr, meta)
    end

    attr_reader :car, :cdr

    def initialize(car, cdr, meta=nil)
      @meta = meta
      @car = car
      @cdr = cdr
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

    def evaluate(env)
      ListEvaluator.evaluate(env, self)
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
    alias to_s inspect
  end
end
