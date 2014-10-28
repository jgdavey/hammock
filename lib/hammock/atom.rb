require 'atomic'
require 'hammock/aref'
require 'hammock/ideref'

module Hammock
  class Atom < ARef
    include IDeref
    def initialize(obj, meta=nil)
      super(meta)
      @state = Atomic.new(obj)
    end

    def deref
      @state.get
    end

    def swap(fn, *args)
      loop do
        v = deref
        new_value = fn.call(v, *args)
        validate(new_value)
        if @state.compare_and_set(v, new_value)
          notify_watches(v, new_value)
          return new_value
        end
      end
    end

    def compare_and_set(old_value, new_value)
      validate(new_value)
      ret = @state.compare_and_set(old_value, new_value)
      notify_watches(old_value, new_value) if ret
      ret
    end

    def reset(new_value)
      old_value = deref
      validate(new_value)
      @state.value = new_value
      notify_watches(old_value, new_value)
      new_value
    end

    def inspect
      prefix = "#<#{self.class}:0x#{self.__id__.to_s(16)}"
      "#{prefix} #{deref.inspect}>"
    end
    alias to_s inspect
  end
end
