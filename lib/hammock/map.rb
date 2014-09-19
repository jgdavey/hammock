require 'hamster/hash'
module Hammock
  class Map < Hamster::Hash
    def self.from_array(array)
      map = new
      array.each_slice(2) do |pair|
        map = map.put(pair.first, pair.last)
      end
      map
    end
  end
end
