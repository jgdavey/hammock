require 'hamster/hash'

module Hammock
  class Map < Hamster::Hash
    include Meta

    def self.alloc_from(map, meta=nil)
      map.send(:transform) { @meta = meta }
    end

    def self.create(coll)
      if Map === coll
        coll
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
      super()
    end

    def conj(pair)
      return merge(pair) if Map === pair
      unless pair.respond_to?(:to_a)
        raise "You passed #{pair} as an argument to conj, but needs an Array-like arg"
      end
      put *pair
    end

    def evaluate(env)
      ret = []
      each do |k,v|
        ret << [k.evaluate(env), v.evaluate(env)]
      end
      self.class.from_pairs(ret)
    end

    alias assoc put

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
