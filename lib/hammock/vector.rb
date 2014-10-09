require 'hamster/vector'
require 'delegate'

module Hammock
  class Vector < Hamster::Vector
    include Meta
    NoMissing = Object.new

    alias empty clear
    alias val_at get

    def self.alloc_from(vec, meta = nil)
      vec.send(:transform) { @meta = meta }
    end

    def self.create(coll)
      if Vector === coll
        coll
      else
        from_array(coll.to_a)
      end
    end

    def self.from_array(items)
      items.reduce(EmptyVector) { |vector, item| vector.add(item) }
    end

    def initialize(meta = nil)
      super()
      @meta = meta
    end

    def assoc_n(idx, obj)
      if idx == count
        add(obj)
      else
        set(idx, obj)
      end
    end

    alias assoc assoc_n
    alias conj add

    def map(&block)
      return self unless block_given?
      reduce(self.class.new) { |vector, item| vector.add(yield(item)) }
    end

    def fetch(n, missing=NoMissing)
      if n >= count
        if missing == NoMissing
          raise IndexError
        else
          missing
        end
      else
        get(n)
      end
    end

    def evaluate(env)
      map { |e| e.evaluate(env) }
    end

    def inspect
      "[#{self.map(&:inspect).to_a.join(' ')}]"
    end

    class SubVector
      include Meta
      attr_reader :start_idx, :end_idx, :v

      def self.alloc_from(subvec, meta)
        new(meta, subvec.v, subvec.start_idx, subvec.end_idx)
      end

      def initialize(meta, vec, start_idx, end_idx)
        @meta = meta
        if SubVector === vec
          start_idx += vec.start_idx
          end_idx += vec.end_idx
          vec = vec.v
        end
        @v, @start_idx, @end_idx = vec, start_idx, end_idx
      end

      def to_a
        a = @v.to_a
        a[start_idx..end_idx]
      end

      def count
        @end_idx - @start_idx
      end

      def add(obj)
        self.class.new(meta, v.assoc_n(@end_idx, obj), @start_idx, @end_idx + 1)
      end

      alias conj add
      alias cons add

      def nth(i)
        if (@start_idx + i) >= @end_idx || i < 0
          raise IndexError, "Index #{i} out of bounds."
        end
        return v.nth(@start_idx + i);
      end

      def assoc_n(i, obj)
        if (@start_idx + i) > @end_idx
          raise IndexError, "Index #{i} out of bounds."
        elsif (@start_idx + i) == @end_idx
          cons(val)
        else
          self.class.new v.assoc_n(@start_idx + i, obj), @start_idx, @end_idx
        end
      end

      def inspect
        "[#{to_a.map(&:inspect).join(' ')}]"
      end
    end
  end

  EmptyVector = Vector.new
end
