require 'atomic'
require 'hammock/errors'
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
      @aliases = Atomic.new(Map.new)
    end

    def ==(other)
      self.object_id == other.object_id
    end

    def aliases
      @aliases.value
    end

    def mappings
      @mappings.value
    end

    def publics
      ret = []
      mappings.each do |k,v|
        if Var === v && v.ns == self && v.public?
          ret << [k,v]
        end
      end
      Map.from_pairs(ret)
    end

    def interns
      ret = []
      mappings.each do |k,v|
        if Var === v && v.ns == self
          ret << [k,v]
        end
      end
      Map.from_pairs(ret)
    end

    def refers
      ret = []
      mappings.each do |k,v|
        if Var === v && v.ns != self
          ret << [k,v]
        end
      end
      Map.from_pairs(ret)
    end

    def add_alias(sym, ns)
      sym = self.class.name_only(sym)
      @aliases.update do |map|
        map.assoc(sym, ns)
      end
    end

    def remove_alias(sym)
      sym = self.class.name_only(sym)
      @aliases.update do |map|
        map.dissoc(sym)
      end
    end

    def lookup_alias(name)
      name = self.class.name_only(name)
      aliases[name]
    end

    def find_var(name)
      name = self.class.name_only(name)
      mappings[name]
    end

    def unmap(symbol)
      sym = Symbol.intern(symbol)
      if sym.ns
        raise Error, "Can't unmap a ns-qualified symbol"
      end
      @mappings.update do |map|
        map.dissoc(sym.name)
      end
      nil
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
      var = Var.new(self, symbol)
      @mappings.update do |mappings|
        mappings.assoc(sym.name, var)
      end
      var
    end

    def refer(symbol, var)
      sym = Symbol.intern(symbol)
      if sym.ns
        raise ArgumentError, "Can't intern a ns-qualified symbol"
      end

      if obj = find_var(symbol)
        if obj == var
          return var
        else
          # warn on redefine
        end
      end

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
