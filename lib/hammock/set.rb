require 'hamster/set'

module Hammock
  class Set < Hamster::Set
    def self.from_array(items)
      items.reduce(new) { |set, item| set.add(item) }
    end
  end
end
