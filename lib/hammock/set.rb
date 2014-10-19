require 'hamster/immutable'
require 'hamster/trie'

require 'hammock/ipersistent_collection'
require 'hammock/meta'
require 'hammock/ifn'
require 'hammock/ilookup'

module Hammock
  class Set
    include Hamster::Immutable
    include IPersistentCollection
    include Meta
    include IFn
    include ILookup

    Undefined = Object.new

    def self.alloc_from(other, meta=nil)
      new(meta).tap do |coll|
        coll.instance_variable_set(:@trie, other.instance_variable_get(:@trie))
      end
    end

    def self.create(coll)
      if self === coll
        coll
      else
        from_array(coll.to_a)
      end
    end

    def self.from_array(items)
      items.reduce(new) { |set, item| set.add(item) }
    end

    def initialize(meta=nil, trie=Hamster::EmptyTrie)
      @meta = meta
      @trie = trie
    end

    def empty?
      @trie.empty?
    end

    def size
      @trie.size
    end
    alias count size
    alias length size

    def add(item)
      transform_unless(include?(item)) { @trie = @trie.put(item, nil) }
    end
    alias conj add
    alias cons add

    def delete(item)
      trie = @trie.delete(item)
      transform_unless(trie.equal?(@trie)) { @trie = trie }
    end
    alias remove delete

    def each
      return self unless block_given?
      @trie.each { |entry| yield(entry.key) }
    end

    def map
      return self unless block_given?
      return self if empty?
      transform do
        @trie = @trie.reduce(Hamster::EmptyTrie) do |trie, entry|
          trie.put(yield(entry.key), nil)
        end
      end
    end

    def reduce(memo = Undefined)
      each do |item|
        memo = memo.equal?(Undefined) ? item : yield(memo, item)
      end if block_given?
      memo unless memo.equal?(Undefined)
    end

    def any?
      return any? { |item| item } unless block_given?
      each { |item| return true if yield(item) }
      false
    end

    def include?(object)
      has_key?(object)
    end

    def has_key?(key)
      @trie.has_key?(key)
    end
    alias key? has_key?

    def fetch(object, default=Undefined)
      if has_key?(object)
        object
      elsif !default.equal?(Undefined)
        default
      end
    end
    alias call fetch
    alias val_at fetch

    def get(object)
      object if has_key?(object)
    end

    def seq
      Sequence.from_array(to_a)
    end

    def evaluate(env)
      map { |e| e.evaluate(env) }
    end

    def eql?(other)
      instance_of?(other.class) && @trie.eql?(other.instance_variable_get(:@trie))
    end
    alias == eql?

    def hash
      reduce(0) { |hash, item| (hash << 5) - hash + item.hash }
    end

    def empty
      self.class.new(meta)
    end

    def to_a
      ret = []
      each do |obj|
        ret << obj
      end
      ret
    end

    def inspect
      "\#{#{to_a.map(&:inspect).join(' ')}}"
    end
  end
end
