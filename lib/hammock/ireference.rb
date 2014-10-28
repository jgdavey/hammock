require 'hammock/meta'

module Hammock
  module IReference
    include Meta
    def reset_meta(meta)
      @meta = meta
    end

    def alter_meta(fn, args)
      args = [@meta] + args.to_a
      @meta = fn.invoke(*args)
    end
  end
end
