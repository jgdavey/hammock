require 'hamster/set'

module Hammock
  class Set < Hamster::Set
    include Meta

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

    def initialize(meta=nil)
      @meta = meta
      super()
    end

    alias conj add
  end
end
