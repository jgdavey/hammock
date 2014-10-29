require 'hammock/errors'

module Hammock
  class ArrayChunk
    Undefined = Object.new

    def initialize(array, offset, endi=nil)
      @array = array
      @offset = offset
      @end = endi || array.length
    end

    def fetch(i, not_found=Undefined)
      if not_found == Undefined || (i >= 0 && i < count)
        @array[@offset + i]
      else
        not_found
      end
    end
    alias nth fetch

    def count
      @end - @offset
    end
    alias size count
    alias length count

    def drop_first
      if @offset == @end
        raise Error, "drop_first of empty chunk"
      else
        self.class.new(@array, @offset + 1, @end)
      end
    end

    def reduce(fn, start)
      ret = fn.call(start, @array[@offset])
      return ret if RT.reduced?(ret)

      x = @offset + 1
      while x < @end
        ret = fn.call(ret, @array[x])
        return ret if RT.reduced?(ret)
        x += 1
      end
      ret
    end
  end
end
