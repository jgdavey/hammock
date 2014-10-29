require 'hammock/array_chunk'

module Hammock
  class ChunkBuffer
    def initialize(capacity)
      @buffer = ::Array.new(capacity)
      @end = 0
    end

    def add(obj)
      @buffer[@end] = obj
      @end += 1
    end

    def chunk
      ret = ArrayChunk.new(@buffer, 0, @end)
      @buffer = nil
      ret
    end

    def count
      @end
    end
  end
end
