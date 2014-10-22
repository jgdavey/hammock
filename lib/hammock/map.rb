require 'forwardable'
require 'hamster/immutable'
require 'hamster/trie'

require 'hammock/ipersistent_collection'
require 'hammock/meta'
require 'hammock/ifn'
require 'hammock/ilookup'

module Hammock
  class Map
    include Hamster::Immutable
    include IPersistentCollection
    include Meta
    include IFn
    include ILookup

    Undefined = Object.new

    def self.alloc_from(map, meta=nil)
      map.send(:transform) { @meta = meta }
    end

    def self.create(coll)
      case coll
      when Map
        coll
      when Hash
        from_hash(coll)
      else
        from_array(coll.to_a)
      end
    end

    def self.from_hash(hash = {})
      map = new
      hash.reduce(map) { |m, (k, v)| m.put(k, v) }
    end

    def self.from_array(array)
      map = new
      array.each_slice(2) do |pair|
        map = map.put(pair.first, pair.last)
      end
      map
    end

    def self.from_pairs(array)
      map = new
      array.each do |pair|
        map = map.put(pair.first, pair.last)
      end
      map
    end

    def initialize(meta=nil)
      @meta = meta
      @trie = Hamster::EmptyTrie
    end

    def size
      @trie.size
    end
    alias length size
    alias count size

    def empty?
      @trie.empty?
    end
    alias null? empty?

    def has_key?(key)
      @trie.has_key?(key)
    end
    alias key? has_key?

    def entry_at(key)
      @trie.get(key)
    end

    def get(key)
      if entry = entry_at(key)
        entry.value
      end
    end
    alias [] get

    def fetch(key, default = Undefined)
      entry = @trie.get(key)
      if entry
        entry.value
      elsif default != Undefined
        default
      elsif block_given?
        yield
      else
        raise KeyError.new("key not found: #{key.inspect}")
      end
    end
    alias val_at fetch

    def call(key, default=nil)
      fetch(key, default)
    end

    def put(key, value = Undefined)
      if value.equal?(Undefined)
        put(key, yield(get(key)))
      else
        transform { @trie = @trie.put(key, value) }
      end
    end
    alias assoc put

    def delete(key)
      trie = @trie.delete(key)
      transform_unless(trie.equal?(@trie)) { @trie = trie }
    end
    alias without delete
    alias dissoc delete

    def each
      return self unless block_given?
      @trie.each { |entry| yield(entry.key, entry.value) }
    end

    def reduce(memo)
      return memo unless block_given?
      @trie.reduce(memo) { |memo, entry| yield(memo, entry.key, entry.value) }
    end

    def merge(other)
      transform { @trie = other.reduce(@trie, &:put) }
    end
    alias + merge

    def keys
      reduce(Hammock::Set.new) { |keys, key, value| keys.add(key) }
    end

    def values
      reduce(Hammock::EmptyList.new) { |values, key, value| values.cons(value) }
    end

    def seq
      @trie.reduce(Hammock::EmptyList.new) { |entries, entry| entries.cons(entry)}
    end

    def cons(obj)
      case obj
      when Vector
        assoc(obj.get(0), obj.get(1))
      when Hamster::Trie::Entry
        assoc(obj.key, obj.value)
      else
        # seq?
      end
    end

    def conj(pair)
      return merge(pair) if Map === pair
      unless pair.respond_to?(:to_a)
        raise "You passed #{pair} as an argument to conj, but needs an Array-like arg"
      end
      put *pair
    end

    def empty
      self.class.new(meta)
    end

    def eql?(other)
      instance_of?(other.class) && @trie.eql?(other.instance_variable_get(:@trie))
    end
    alias == eql?

    def hash
      reduce(0) { |hash, key, value| (hash << 32) - hash + key.hash + value.hash }
    end

    def to_a
      ret = []
      each do |k,v|
        ret << [k,v]
      end
      ret
    end
    alias pairs to_a

    def evaluate(env)
      ret = []
      each do |k,v|
        ret << [k.evaluate(env), v.evaluate(env)]
      end
      self.class.from_pairs(ret)
    end

    def inspect
      out = []
      each do |k, v|
        out << "#{k.inspect} #{v.inspect}"
      end
      "{#{out.join(', ')}}"
    end
    alias to_s inspect
  end
end
