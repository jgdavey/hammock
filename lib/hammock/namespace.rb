require 'atomic'
require 'hammock/map'

module Hammock
  NAMESPACES = {}

  class Namespace
    attr_reader :name

    def self.all
      Sequence.from_array NAMESPACES.values
    end

    def self.find(name)
      NAMESPACES[name_only(name)]
    end

    def self.remove(name)
      NAMESPACES.delete(name_only(name))
    end

    def self.name_only(name)
      if Hammock::Symbol === name
        name.name
      else
        name
      end
    end

    def self.find_or_create(name)
      name = name_only(name)
      existing = find(name)
      existing and return existing

      newns = new(name)
      NAMESPACES[name] = newns
    end

    def self.find_item(ns, symbol)
      if symbol.ns == ns.name
        ns.find_var(symbol.name)
      elsif symbol.ns
        mod = find(symbol.ns)
        mod.find_var(symbol.name)
      else
        ns.find_var(symbol.name)
      end
    end

    def initialize(name)
      @name = name
      @mappings = Atomic.new(Map.new)
    end

    def mappings
      @mappings.value
    end

    def find_var(name)
      name = self.class.name_only(name)
      mappings[name]
    end

    def has_var?(name)
      name = self.class.name_only(name)
      mappings.key?(name)
    end

    def find_var!(name)
      find_var(name) or raise "Unable to find #{name} within #@name"
    end

    def intern(symbol)
      sym = Symbol.intern(symbol)
      if sym.ns
        raise ArgumentError, "Can't intern a ns-qualified symbol"
      end
      var = Var.new(name, symbol)
      @mappings.update do |mappings|
        mappings.assoc(sym.name, var)
      end
      var
    end

    def inspect
      "#<Namespace: #@name>"
    end

    def to_s
      @name
    end
  end
end
