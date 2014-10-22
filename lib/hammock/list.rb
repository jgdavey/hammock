require 'thread'
require 'forwardable'
require 'hamster/enumerable'
require 'hammock/set'
require 'hammock/list_evaluator'
require 'hammock/ipersistent_collection'

module Hammock
  module List
    include IPersistentCollection
    include Hamster::Enumerable

    CADR = /^c([ad]+)r$/

    def first; head end
    def null?; empty? end

    def size
      reduce(0) { |memo, item| memo.next }
    end
    alias length size
    alias count size

    def cons(item)
      Sequence.new(item, self)
    end

    def each
      return self unless block_given?
      list = self
      while !list.empty?
        yield(list.head)
        list = list.tail
      end
    end

    def to_a
      ret = []
      each do |obj|
        ret << obj
      end
      ret
    end

    def map(&block)
      return self unless block_given?
      Stream.new do
        next self if empty?
        Sequence.new(yield(head), tail.map(&block))
      end
    end

    def append(other)
      Stream.new do
        next other if empty?
        Sequence.new(head, tail.append(other))
      end
    end
    alias cat append
    alias concat append
    alias + append

    def cycle
      Stream.new do
        next self if empty?
        Sequence.new(head, tail.append(self.cycle))
      end
    end

    def clear
      EmptyList
    end

    def join(sep = "")
      return "" if empty?
      sep = sep.to_s
      tail.reduce(head.to_s.dup) { |result, item| result << sep << item.to_s }
    end

    def last
      list = self
      while !list.tail.empty?
        list = list.tail
      end
      list.head
    end

    def chunk(number)
      Stream.new do
        next self if empty?
        first, remainder = split_at(number)
        Sequence.new(first, remainder.chunk(number))
      end
    end

    def each_chunk(number, &block)
      chunk(number).each(&block)
    end
    alias each_slice each_chunk

    def flatten
      Stream.new do
        next self if empty?
        next head.append(tail.flatten) if head.is_a?(List)
        Sequence.new(head, tail.flatten)
      end
    end

    def group_by(&block)
      return group_by { |item| item } unless block_given?
      reduce(EmptyHash) do |hash, item|
        key = yield(item)
        hash.put(key, (hash.get(key) || EmptyList).cons(item))
      end
    end

    def at(index)
      drop(index).head
    end

    def eql?(other)
      list = self
      loop do
        return true if other.equal?(list)
        return false unless other.is_a?(List)
        return other.empty? if list.empty?
        return false if other.empty?
        return false unless other.head.eql?(list.head)
        list = list.tail
        other = other.tail
      end
    end
    alias == eql?

    def hash
      reduce(0) { |hash, item| (hash << 5) - hash + item.hash }
    end

    def empty
      EmptyList
    end

    def dup
      self
    end
    alias clone dup

    def to_list
      self
    end

    def respond_to?(name, include_private = false)
      super || CADR === name.to_s
    end

    private

    def method_missing(name, *args, &block)
      return accessor($1) if CADR === name.to_s
      super
    end

    def accessor(sequence)
      sequence.reverse.each_char.reduce(self) do |memo, char|
        case char
        when "a" then memo.head
        when "d" then memo.tail
        end
      end
    end
  end

  module EmptyList
    class << self
      include List

      def head
        nil
      end

      def tail
        self
      end

      def seq
        nil
      end

      def with_meta(*)
        self
      end

      def meta; end

      def empty?
        true
      end

      def inspect
        "()"
      end
      alias to_s inspect
    end
  end
end
