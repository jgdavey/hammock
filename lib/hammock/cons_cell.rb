require 'hammock/meta'
require 'hammock/list_evaluator'

module Hammock
  class ConsCell
    include Meta
    include Enumerable

    def self.from_array(array)
      return EmptyList.new if array.empty?
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
      ConsCell.new(item, self)
    end
    alias conj cons

    def evaluate(env)
      ListEvaluator.evaluate(env, self)
    end

    def empty?
      false
    end

    def each
      cell = self
      loop do
        yield cell.car unless cell.empty?
        break unless cell.next?
        cell = cell.cdr
      end
      self
    end

    def inspect
      "(#{map(&:inspect).join(' ')})"
    end
    alias to_s inspect
  end

  class EmptyList < ConsCell
    def initialize(meta=nil)
      super(nil, nil, meta)
    end

    def cons(item)
      ConsCell.new(item, nil)
    end

    def evaluate(_)
      self
    end

    def empty?; true; end
  end
end
