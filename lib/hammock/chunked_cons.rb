require 'hammock/meta'
require 'hammock/ichunked_seq'
require 'hammock/iseq'

module Hammock
  class ChunkedCons
    include Meta
    include IChunkedSeq
    include ISeq

    def initialize(chunk, more, meta=nil)
      @chunk = chunk
      @_more = more
      @meta = meta
    end

    def with_meta(meta)
      if @meta == meta
        self
      else
        self.class.new(@chunk, @_more, meta)
      end
    end

    def first
      @chunk.nth(0)
    end
    alias head first

    def rest
      if @chunk.count > 1
        self.class.new(@chunk.drop_first, @_more)
      elsif @_more.nil?
        EmptyList.new
      else
        @_more
      end
    end

    def next
      if @chunk.count > 1
        self.class.new(@chunk.drop_first, @_more)
      else
        chunked_next
      end
    end
    alias tail next

    def chunked_first
      @chunk
    end

    def chunked_next
      chunked_rest.seq
    end

    def chunked_rest
      if @_more.nil?
        EmptyList.new
      else
        @_more
      end
    end

    def seq
      self
    end
  end
end
