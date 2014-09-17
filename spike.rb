class PersistentVector
  class Node
    attr_reader :edit, :array

    def initialize(edit, array=nil)
      @edit, @array = edit, array || []
    end
  end

  NOEDIT = nil
  EMPTY_NODE = Node.new(NOEDIT, [])

  attr_reader :shift, :root, :tail, :cnt, :_meta
  protected :shift, :root, :tail, :cnt, :_meta

  def initialize(cnt, shift, root, tail, meta=nil)
    @cnt = cnt
    @shift = shift
    @root, @tail, @_meta = root, tail, meta
  end

  EMPTY = self.new(0, 5, EMPTY_NODE, [])

  def self.create(*items)
    ret = EMPTY
    items.each do |i|
      ret = ret.cons(i)
      puts ret.inspect
    end
    ret
  end

  def tailoff
    if @cnt < 32
      0
    else
      ((@cnt - 1) >> 5) << 5
    end
  end

  def arrayFor(i)
    if i >= 0 && i < cnt
      if i >= tailoff
        return tail
      else
        node = root
        level = shift
        while level > 0
          node = node.array[(i >> level) & 0x01f];
          level -= 5
        end
        node.array
      end
    else
      raise ArgumentError, "index #{i} out of bounds"
    end
  end

  def nth(i, not_found=nil)
    if not_found
      if i >= 0 && i < cnt
        node = arrayFor(i)
        node[i & 0x01f]
      else
        not_found
      end
    else
      node = arrayFor(i)
      node[i & 0x01f]
    end
  end

  alias [] nth

  def cons(val)
    if cnt - tailoff < 32
      new_tail = tail + [val]
      PersistentVector.new(cnt + 1, shift, root, new_tail, _meta)
    else
      tail_node = Node.new(root.edit, tail)
      new_shift = shift
      if (cnt >> 5) > (1 << shift)
        new_root = Node.new(root.edit)
        new_root.array[0] = root
        new_root.array[1] = new_path(root.edit, shift, tail_node)
        new_shift +=5
      else
        new_root = push_tail(shift, root, tail_node)
      end
      PersistentVector.new(cnt + 1, new_shift, new_root, [val], _meta)
    end
  end

  def count
    @cnt
  end

  def with_meta(meta)
    PersistentVector.new(cnt, shift, root, tail, meta)
  end

  def meta
    @_meta
  end

  def empty
    EMPTY.with_meta(meta)
  end

  def assoc_n(i, val)
    if i >= 0 && i < cnt
      if i >= tailoff
        new_tail = tail.dup
        new_tail[i & 0x01f] = val;
        PersistentVector.new(cnt, shift, root, new_tail, _meta);
      else

        PersistentVector.new(cnt, shift, doAssoc(shift, root, i, val), tail, _meta)
      end
    elsif i == cnt
      cons(val)
    else
      raise IndexOutOfBoundsException
    end
  end


  def doAssoc(level, node, i, val)
    ret = Node.new(node.edit, node.array.dup);
    if(level == 0)
      ret.array[i & 0x01f] = val;
    else
      subidx = (i >> level) & 0x01f
      ret.array[subidx] = doAssoc(level - 5, node.array[subidx], i, val);
    end
    ret
  end


  def each(&block)
    start = 0
    i = start
    endit = cnt
    base = i - (i % 32)
    array = (start < cnt) ? arrayFor(i) : nil

    while i < endit
      if i - base == 32
        array = arrayFor(i)
        base += 32
      end
      block.call(array[i & 0x01f])
      i += 1
    end
  end


  private

  def push_tail(level, parent, tail_node)
    subidx = ((cnt - 1) >> level) & 0x01f
    ret = Node.new(parent.edit, parent.array.dup)
    if level == 5
      node_to_insert = tail_node
    else
      child = parent.array[subidx]
      node_to_insert = if child
                         push_tail(level - 5, child, tail_node)
                       else
                         new_path(root.edit, level - 5, tail_node)
                       end
    end
    ret.array[subidx] = node_to_insert
    ret
  end

  def new_path(edit, level, node)
    if level == 0
      node
    else
      ret = Node.new(edit)
      ret.array << new_path(edit, level - 5, node)
      ret
    end
  end

end
