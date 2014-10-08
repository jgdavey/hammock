module Hammock
  NAMESPACES = {}

  class Namespace
    attr_reader :name

    def self.find(name)
      NAMESPACES[name_only(name)]
    end

    def self.remove(name)
      NAMESPACES.delete(name_only(name))
    end

    def self.name_only(name)
      if name.respond_to?(:name)
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
      @symtable = {}
    end

    def find_var(name)
      name = self.class.name_only(name)
      @symtable[name]
    end

    def has_var?(name)
      name = self.class.name_only(name)
      @symtable.key?(name)
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
      @symtable[sym.name] = var
      var
    end
  end
end
