module Hammock
  class Symbol
    include Meta

    attr_reader :name

    def self.intern(*args)
      return args.first if Hammock::Symbol === args.first

      if args.length == 1
        *ns, name = args.first.split("/", 2)
        new(ns.first, name)
      else
        new(*args)
      end
    end

    def self.alloc_from(other, meta)
      new(other.ns, other.name, meta)
    end

    def initialize(ns, name, meta=nil)
      @name, @ns = name, ns
      @name.freeze
      @ns.freeze
      @meta = meta
    end

    def ==(other)
      return false unless other.respond_to?(:name)
      return false unless other.respond_to?(:ns)
      other.ns == ns && other.name == name
    end

    def evaluate(env)
      return env[name] if env.key?(name)
      namespace = env["__namespace__"] || context
      if namespace.has_var?(name) && (v = namespace.find_var(name))
        v.deref
      elsif constant
        constant
      else
        raise "Unable to resolve symbol #@name in this context"
      end
    end

    def constant
      return @constant if defined?(@constant)
      n = name.gsub(".", "::")
      @constant = begin
                    Object.const_defined?(n) && Object.const_get(n)
                  rescue NameError
                  end
    end

    def ns
      @ns && Namespace.find(@ns)
    end

    def inspect
      @to_s ||= if @ns
                  "#@ns/#@name"
                else
                  name
                end
    end
    alias to_s inspect

    def context
      ns || Hammock::RT::CURRENT_NS.deref
    end
  end
end
