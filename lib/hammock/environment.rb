module Hammock
  class Environment
    attr_reader :frame

    def initialize(frame)
      unless Hammock::Map === frame
        frame = Hammock::Map.new frame
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
      @frame[name]
    end
    alias [] find

    def key?(name)
      @frame.key?(name)
    end

    def inspect
      parts = []
      f = frame.each do |k,v|
        parts << "#{k} => #{v.class}"
      end
      "#<#{self.class} frame=#{parts.join("\n")}"
    end
    alias to_s inspect
  end
end
