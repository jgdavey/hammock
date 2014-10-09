require 'hammock/list'
require 'forwardable'

module Hammock
  class Stream
    extend Forwardable
    include List
    include Meta

    def initialize(meta=nil,&block)
      @meta = meta
      @block = block
      @lock = Mutex.new
    end

    def_delegators :target, :head, :tail, :empty?

    protected

    def vivify
      @lock.synchronize do
        unless @block.nil?
          @target = @block.call
          @block = nil
        end
      end
      @target
    end

    private

    def target
      list = vivify
      while list.is_a?(Stream)
        list = list.vivify
      end
      list
    end
  end
end
