require 'hamster/immutable'

require 'hammock/ipersistent_collection'
require 'hammock/meta'
require 'hammock/ifn'
require 'hammock/ilookup'

module Hammock
  class Vector
    include Hamster::Immutable
    include IPersistentCollection
    include Meta
    include IFn
    include ILookup

    Undefined = Object.new

    BLOCK_SIZE = 32
    INDEX_MASK = BLOCK_SIZE - 1
    BITS_PER_LEVEL = 5

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

    def initialize(meta=nil)
      @meta = meta
      @levels = 0
      @root = []
      @size = 0
    end

    def empty?
      @size == 0
    end
    alias null? empty?

    def size
      @size
    end
    alias count size
    alias length size

    def first
      get(0)
    end
    alias head first

    def last
      get(-1)
    end

    def add(item)
      transform do
        update_leaf_node(@size, item)
        @size += 1
      end
    end
    alias cons add
    alias conj add

    def concat(arraylike)
      arraylike.to_a.reduce(self) do |v, item|
        v.add(item)
      end
    end

    def set(index, item = Undefined)
      return set(index, yield(get(index))) if item.equal?(Undefined)
      raise IndexError if empty? or index == @size
      raise IndexError if index.abs > @size
      return set(@size + index, item) if index < 0
      transform do
        update_leaf_node(index, item)
      end
    end

    def get(index)
      return nil if empty? or index == @size
      return nil if index.abs > @size
      return get(@size + index) if index < 0
      leaf_node_for(@root, root_index_bits, index)[index & INDEX_MASK]
    end
    alias nth get

    def fetch(n, missing=Undefined)
      unless Integer === n
        raise "Index must be an Integer. Received #{n.inspect}"
      end
      if n >= count
        if missing == Undefined
          raise IndexError
        else
          missing
        end
      else
        get(n)
      end
    end
    alias val_at fetch

    def call(n, missing=nil)
      fetch(n, missing)
    end

    def each(&block)
      return self unless block_given?
      traverse_depth_first(&block)
      nil
    end

    def map(&block)
      return self unless block_given?
      reduce(EmptyVector) { |vector, item| vector.add(yield(item)) }
    end

    def reduce(memo = Undefined)
      each do |item|
        memo = memo.equal?(Undefined) ? item : yield(memo, item)
      end if block_given?
      memo unless memo.equal?(Undefined)
    end

    def empty
      self.class.new(meta)
    end

    def eql?(other)
      return true if other.equal?(self)
      return false unless instance_of?(other.class) && @size == other.size
      @root.eql?(other.instance_variable_get(:@root))
    end
    alias == eql?

    def to_a
      ret = []
      each do |obj|
        ret << obj
      end
      ret
    end

    def assoc_n(idx, obj)
      if idx == count
        add(obj)
      else
        set(idx, obj)
      end
    end

    alias assoc assoc_n

    def seq
      return if count == 0
      Sequence.from_array(to_a)
    end

    def evaluate(env)
      map { |e| e.evaluate(env) }
    end

    def inspect
      "[#{self.map(&:inspect).to_a.join(' ')}]"
    end

    private

    def traverse_depth_first(node = @root, level = @levels, &block)
      return node.each(&block) if level == 0
      node.each { |child| traverse_depth_first(child, level - 1, &block) }
    end

    def leaf_node_for(node, child_index_bits, index)
      return node if child_index_bits == 0
      child_index = (index >> child_index_bits) & INDEX_MASK
      leaf_node_for(node[child_index], child_index_bits - BITS_PER_LEVEL, index)
    end

    def update_leaf_node(index, item)
      copy_leaf_node_for(new_root, root_index_bits, index)[index & INDEX_MASK] = item
    end

    def copy_leaf_node_for(node, child_index_bits, index)
      return node if child_index_bits == 0
      child_index = (index >> child_index_bits) & INDEX_MASK
      if child_node = node[child_index]
        child_node = child_node.dup
      else
        child_node = []
      end
      node[child_index] = child_node
      copy_leaf_node_for(child_node, child_index_bits - BITS_PER_LEVEL, index)
    end

    def new_root
      if full?
        @levels += 1
        @root = [@root]
      else
        @root = @root.dup
      end
    end

    def full?
      (@size >> root_index_bits) > 0
    end

    def root_index_bits
      @levels * BITS_PER_LEVEL
    end

    class SubVector
      include IPersistentCollection
      include Meta
      include IFn
      include ILookup
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

      def size
        @end_idx - @start_idx
      end
      alias count size
      alias length size

      def add(obj)
        self.class.new(meta, v.assoc_n(@end_idx, obj), @start_idx, @end_idx + 1)
      end
      alias conj add
      alias cons add

      def get(i)
        if (@start_idx + i) >= @end_idx || i < 0
          raise IndexError, "Index #{i} out of bounds."
        end
        return v.nth(@start_idx + i);
      end
      alias nth get
      alias val_at get

      def fetch(n, missing=Undefined)
        if n >= count
          if missing == Undefined
            raise IndexError
          else
            missing
          end
        else
          get(n)
        end
      end

      def call(n, missing=nil)
        fetch(n, missing)
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
      alias assoc assoc_n

      def inspect
        "[#{to_a.map(&:inspect).join(' ')}]"
      end
    end
  end

  EmptyVector = Vector.new
end
