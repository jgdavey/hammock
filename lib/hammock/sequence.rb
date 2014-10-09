require 'hammock/list'

module Hammock
  class Sequence
    include List
    include Meta

    attr_reader :head, :tail

    def self.from_array(array)
      array.to_a.reverse.reduce(Hammock::EmptyList) do |prev, el|
        new(el, prev)
      end
    end

    def self.alloc_from(other, meta=nil)
      new(other.head, other.tail, meta)
    end

    def initialize(head, tail = Hammock::EmptyList, meta=nil)
      @meta = nil
      @head = head
      @tail = tail
    end

    def car
      head
    end

    def cdr
      tail
    end

    def ==(other)
      return false unless other.respond_to?(:tail)
      first == other.first && tail == other.tail
    end

    def evaluate(env)
      ListEvaluator.evaluate(env, self)
    end

    def empty?
      false
    end
  end
end
