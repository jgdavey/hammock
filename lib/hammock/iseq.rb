module Hammock
  module ISeq
    def first; end
    def next; end
    def rest; end

    # override
    def cons(obj)
      Sequence.new(obj, self)
    end
  end
end
