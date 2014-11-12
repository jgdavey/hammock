module Hammock
  module IChunkedSeq
    Undefined = Object.new

    def nth(n, notfound=Undefined)
      list = seq

      n.times do
        list = list.rest
      end

      if list.empty?
        if notfound == Undefined
          raise IndexError
        else
          notfound
        end
      else
        list.first
      end
    end
  end
end
