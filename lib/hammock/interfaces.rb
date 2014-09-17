module IPersistentCollection
  # returns int
  def count; end

  # returns a collection
  def cons(obj); end

  # returns empty collection
  def empty(); end

  # returns true or false
  # def equiv(obj); end
end

module IPersistentVector
  # returns int
  def length; end

  # returns IPersistentVector
  def assocN(i, obj); end

  # returns IPersistentVector
  def cons(obj); end
end

module ILookup
  def val_at(key, not_found=nil); end
end

module Associative
  # returns MapEntry
  def entry_at(key); end

  # returns Associative
  def assoc(key, val); end
end

module IPersistentMap
  # returns IPersistentMap
  def assoc(key, val); end

  # returns IPersistentMap
  def assocEx(key, val); end

  # returns IPersistentMap
  def without(key); end
end

module IMeta
  def meta; end
end

module IObj
  # returns IObj
  def with_meta(meta); end
end

module ISeq
  def first; end
  def next; end
  def more; end
  def cons(obj); end
end

module IFn
  def invoke(*args); end
end

module IReduce
  def reduce(fn, start=nil); end
end

# module IEditableCollection
#   def as_transient; end
# end

# module ITransientCollection
#   def conj(obj); end
#   def persistent; end
# end
