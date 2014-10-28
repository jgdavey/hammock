require 'hammock/ideref'

module Hammock
  class Var
    include Meta
    include IFn

    attr_reader :ns, :symbol, :root

    def self.intern(*args)
      new(*args)
    end

    def initialize(*args)
      if args.length > 1
        @ns, @symbol, @root = args
      else
        @root = args.first
      end

      @meta = nil
      @dynamic = false
      @public = true
      @rev = 0
    end

    def trace
      return unless meta
      "#{meta[:file]}:#{meta[:line]} in #@symbol"
    end

    def macro!
      @meta = meta.assoc :macro, true
    end

    def dynamic!
      @dynamic = true
      self
    end

    def dynamic?
      @dynamic
    end

    def public?
      @public
    end

    def private?
      !@public
    end

    def deref
      @root
    end

    def bind_root(val)
      @rev += 1
      @root = val
    end

    def unbind_root
      @root = nil
    end

    def meta=(meta)
      if meta[:private]
        @public = false
      end
      @meta = meta
    end

    def evaluate(env)
      @root
    end

    def call(*args)
      @root.call(*args)
    end

    def to_s
      if @ns
        "#'#{@ns.name}/#{symbol.name}"
      else
        n = symbol ? symbol.to_s : "--unnamed--"
        "#<Var: #{n}>"
      end
    end
    alias inspect to_s
  end
end
