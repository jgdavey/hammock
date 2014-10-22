module Hammock
  class Error < StandardError
  end

  class CompileError < Error
    def initialize(form, msg=nil)
      parts = [msg || "Error compiling form"]
      if Meta === form && form.meta && form.meta[:line]
        parts << "Originated from #{form.meta[:file]}:#{form.meta[:line]}, col #{form.meta[:column]}"
      end
      super(parts.join("\n"))
    end
  end
end
