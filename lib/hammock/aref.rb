require 'hammock/map'
require 'hammock/errors'
require 'hammock/ireference'

module Hammock
  class ARef
    include IReference

    attr_writer :validator

    def initialize(meta=nil)
      @meta = meta
      @watches = Map.new
      @validator = nil
    end

    def validate(fn_or_obj, obj=nil)
      if obj
        fn = fn_or_obj
      else
        obj = fn_or_obj
        fn = validator
      end

      if fn && !fn.call(obj)
        raise Error, "Illegal reference state"
      end
    end

    def add_watch(key, cb)
      @watches = watches.assoc(key, cb)
    end

    def remove_watch(key)
      @watches = watches.without(key)
    end

    def notify_watches(oldval, newval)
      return if watches.count == 0
      watches.each do |key, fn|
        if fn
          fn.call(key, self, oldval, newval)
        end
      end
    end

    def watches
      @watches
    end

    protected

    def validator
      @validator
    end
  end
end
