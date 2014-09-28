require 'hamster/vector'

module Hammock
  class Vector < Hamster::Vector
    include Meta

    alias empty clear
    alias val_at get

    def self.alloc_from(vec, meta = nil)
      vec.send(:transform) { @meta = meta }
    end

    def self.from_array(items)
      items.reduce(EmptyVector) { |vector, item| vector.add(item) }
    end

    def initialize(meta = nil)
      super()
      @meta = meta
    end

    def assocN(idx, obj)
      if idx == count
        add(obj)
      else
        set(idx, obj)
      end
    end

    alias assoc assocN

    def call(n, missing=nil)
      if n >= count
        missing
      else
        get(n)
      end
    end

    def inspect
      "[#{self.map(&:inspect).to_a.join(' ')}]"
    end
  end

  EmptyVector = Vector.new
end
