require 'hamster/vector'

class Vector < Hamster::Vector
  alias empty clear
  alias val_at get

  attr_reader :meta

  def self.alloc_from(vec, meta = nil)
    new(meta).tap do |new_vec|
      new_vec.instance_variable_set(:@level, vec.instance_variable_get(:@level))
      new_vec.instance_variable_set(:@size, vec.instance_variable_get(:@size))
      new_vec.instance_variable_set(:@root, vec.instance_variable_get(:@root))
    end
  end

  def initialize(meta = nil)
    super()
    @meta = meta
  end

  def assocN(idx, obj)
    if idx == count
      add(obj)
    else
      set(idx, obj)
    end
  end

  alias assoc assocN

  def with_meta(meta)
    self.class.alloc_from(self, meta)
  end

  def invoke(n, missing=nil)
    if n >= count
      missing
    else
      get(n)
    end
  end
end
