require 'hammock/meta'
require 'hammock/list'

module Hammock
  class Sequence
    include List
    include Meta

    attr_reader :head, :tail

    def self.from_array(array)
      return EmptyList.new if array.nil? || array.empty?
      array.to_a.reverse.inject(EmptyList.new) do |prev, el|
        new(el, prev)
      end
    end

    def self.alloc_from(other, meta=nil)
      new(other.head, other.tail, meta)
    end

    def initialize(head, tail = Hammock::EmptyList.new, meta=nil)
      @meta = meta
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

    def seq
      self
    end

    def evaluate(env)
      Compiler.evaluate(env, self)
    end

    def with_meta(meta)
      self.class.new(head, tail, meta)
    end

    def inspect
      "(#{to_a.map(&:inspect).join(' ')})"
    end
    alias to_s inspect

    def empty?
      false
    end
  end
end
