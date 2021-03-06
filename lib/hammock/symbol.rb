module Hammock
  class Symbol
    include Meta

    attr_reader :name, :ns

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
      new(other.instance_variable_get("@ns"), other.name, meta)
    end

    def initialize(ns, name, meta=nil)
      @name = name
      @ns = ns if ns && !ns.to_s.empty?
      @name.freeze
      @ns.freeze
      @meta = meta
    end

    def ==(other)
      return false unless other.respond_to?(:name)
      return false unless other.respond_to?(:ns)
      other.ns == ns && other.name == name
    end
    alias eql? ==

    def constant
      return @constant if defined?(@constant)
      segments = name.split(".")
      begin
        @constant = segments.reduce(Object) do |parent, n|
          parent.const_defined?(n) && parent.const_get(n)
        end
      rescue NameError => e
        $stderr.puts e
      end
    end

    def inspect
      @to_s ||= if @ns
                  "#@ns/#@name"
                else
                  name
                end
    end
    alias to_s inspect

    def namespace(contextual=nil)
      inns = Hammock::RT::CURRENT_NS.deref
      prefer_ns = contextual || inns
      if @ns
        prefer_ns.lookup_alias(@ns) || Namespace.find(@ns)
      else
        prefer_ns
      end
    end
  end
end
