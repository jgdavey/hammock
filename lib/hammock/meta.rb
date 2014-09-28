module Hammock
  # meta should always be a persistent map
  module Meta
    def meta
      @meta
    end

    def with_meta(meta)
      self.class.alloc_from(self, meta)
    end
  end
end
