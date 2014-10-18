module Hammock
  class Environment
    attr_reader :frame

    def initialize(frame)
      unless Hammock::Map === frame
        frame = Hammock::Map.create frame
      end
      @frame = frame
    end

    def bind(name, val)
      self.class.new(@frame.assoc name, val)
    end

    def merge(env)
      self.class.new(@frame.merge(env.frame))
    end

    def find(name)
      if item = @frame[name]
        if Var === item && item.dynamic?
          item.deref
        else
          item
        end
      end
    end
    alias [] find

    def key?(name)
      @frame.key?(name)
    end

    def inspect
      parts = []
      f = frame.each do |k,v|
        parts << " #{k}\t#{v.inspect}"
      end
      "#<#{self.class}\n#{parts.join("\n")}"
    end
    alias to_s inspect
  end
end
