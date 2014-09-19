module Hammock
  class Symbol
    attr_reader :name, :ns

    def self.intern(*args)
      if args.length == 1
        *ns, name = args.first.split("/", 2)
        new(ns.first, name)
      else
        new(*args)
      end
    end

    def initialize(ns, name)
      @name, @ns = name, ns
    end

    def ==(other)
      return false unless other.respond_to?(:name)
      if @ns
        return false unless other.respond_to?(:ns)
        other.ns == @ns && other.name == @name
      else
        other.name == @name
      end
    end
  end
end
