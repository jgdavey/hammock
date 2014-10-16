require 'atomic'
require 'hammock/meta'
require 'hammock/list'

module Hammock
  class LazySequence
    include List
    include Meta

    attr_reader :s

    def self.alloc_from(ls, meta=nil)
      new(meta, ls.fn, ls.s)
    end

    def initialize(meta=nil, fn=nil, s=nil)
      @meta = meta
      @fn = Atomic.new(fn)
      @s = s
      @target = nil
    end

    def seq
      list = sval
      while list.is_a?(LazySequence)
        list = list.sval
      end
      @s = RT.seq(list)
    end

    def empty?
      seq.nil?
    end

    def head
      seq
      return nil if @s.nil?
      @s.head
    end

    def tail
      seq
      return nil if @s.nil?
      @s.tail
    end

    def more
      seq
      return EmptyList if @s.nil?
      @s.more
    end

    def inspect
      seq.inspect
    end

    def fn
      @fn.value
    end

    protected

    def sval
      unless fn.nil?
        @fn.update do |v|
          @target = v.apply
          nil
        end
      end
      @target.nil? ? @s : @target
    end
  end
end
