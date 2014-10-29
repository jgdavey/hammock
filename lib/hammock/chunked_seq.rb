require 'hammock/meta'
require 'hammock/array_chunk'
require 'hammock/ichunked_seq'
require 'hammock/iseq'

module Hammock
  class ChunkedSeq
    include IChunkedSeq
    include ISeq
    include Meta

    def initialize(vec, i, offset, node=nil, meta=nil)
      @vec = vec
      @i = i
      @offset = offset
      @meta = meta
      @node = node || @vec.array_for(i)
    end

    def chunked_first
      ArrayChunk.new(@node, @offset)
    end

    def chunked_next
      if @i + @node.length < @vec.count
        ChunkedSeq.new(vec, @i + @node.length, 0)
      end
    end

    def chunked_rest
      seq = chunked_next
      return EmptyList.new if seq.nil?
      seq
    end

    def with_meta(meta)
      self.class.new(@vec, @i, @offset, @node, meta)
    end

    def first
      @node[@offset]
    end
    alias head first

    def next
      if @offset + 1 < @node.length
        ChunkedSeq.new(@vec, @i, @offset + 1, @node)
      else
        chunked_next
      end
    end

    def rest
      t = self.next
      return EmptyList.new if t.nil?
      t
    end
    alias tail rest

    def seq
      self
    end

    def empty?
      seq.nil?
    end

    def count
      @vec.count - (@i + @offset)
    end
  end
end
