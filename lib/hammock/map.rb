require 'hamster/hash'

module Hammock
  class Map < Hamster::Hash
    include Meta

    def self.alloc_from(map, meta=nil)
      map.send(:transform) { @meta = meta }
    end

    def self.from_array(array)
      map = new
      array.each_slice(2) do |pair|
        map = map.put(pair.first, pair.last)
      end
      map
    end

    def initialize(meta=nil)
      @meta = meta
      super()
    end

    def conj(pair)
      put *pair
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
