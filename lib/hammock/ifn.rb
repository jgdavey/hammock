module Hammock
  module IFn
    # def call(*args)
    # end

    def apply_to(sequence)
      call(*sequence.to_a)
    end
  end
end
