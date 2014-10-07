require 'hammock/vector'

module Hammock
  class RecurLocals
    def initialize(rebinds=[])
      unless Hammock::Vector === rebinds
        rebinds = Hammock::Vector.from_array(rebinds)
      end
      @rebinds = rebinds
    end

    def to_a
      @rebinds.to_a
    end
  end
end
