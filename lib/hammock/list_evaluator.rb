require 'hammock/symbol'
require 'hammock/errors'

module Hammock
  module ListEvaluator
    DOT = Symbol.intern(".")
    NEW = Symbol.intern("new")
    extend self

    def namespace(env, sym)
      env["__namespace__"] || sym.ns || RT::CURRENT_NS.deref
    end

    def find_var(env, sym)
      namespace(env, sym).find_var(sym)
    end

    def macro?(form)
      Meta === form && form.meta && form.meta[:macro]
    end

    def expand_method(form)
      meta = form.meta
      method, target, *args = *form
      args = Sequence.from_array(args)
      method = Symbol.intern(method.name[1..-1])
      if args
        args = args.cons(method)
      else
        args = method
      end
      Sequence.from_array([DOT, target, args]).with_meta(meta)
    end

    def expand_new(form)
      meta = form.meta
      klass, *args = *form
      args = Sequence.from_array(args)
      klass = Symbol.intern(klass.name[0..-2])
      if args
        args = args.cons(NEW)
      else
        args = NEW
      end
      Sequence.from_array([DOT, klass, args]).with_meta(meta)
    end

    def macroexpand1(form, env=RT.global_env)
      form, _ = _macroexpand1(env, form)
      form
    end

    def _macroexpand1(env, form)
      return form, false unless form.is_a?(List)
      sym = form.car
      return form, false unless Hammock::Symbol === sym
      meta = form.meta

      if item = find_var(env, sym)
        dreffed = item.deref
        if macro?(item) || macro?(dreffed)
          begin
            form = dreffed.call(form, env, *form.cdr)
            if meta && Meta === form
              form = form.with_meta(meta)
            end
          rescue => e
            raise Hammock::CompileError.new(form, "Error compiling: #{e}")
          end
          return form, true
        else
          return form, false
        end
      elsif sym.name == DOT.name
        return form, false
      elsif sym.name.start_with?(DOT.name)
        form = expand_method(form)
        return form, false
      elsif sym.name.end_with?(DOT.name)
        form = expand_new(form)
        return form, false
      else
        return form, false
      end
    end

    def special(form)
      return unless form.is_a?(List)
      RT.special(form.car)
    end

    def macroexpand(env, form)
      return form unless List === form && Hammock::Symbol === form.first
      ret = true
      spec = nil
      while ret && !spec
        form, ret = _macroexpand1(env, form)
        spec = special(form) if form
      end
      form
    end

    def compile(env, form)
      return form unless IPersistentCollection === form
      meta = form.meta
      new_form = form.to_a.map do |f|
        compile(env, f)
      end
      case form
      when List
        list = Sequence.from_array(new_form).with_meta(meta)
        macroexpand(env, list)
      when Vector
        Vector.from_array(new_form).with_meta(meta)
      when Map
        Map.from_pairs(new_form).with_meta(meta)
      when Set
        Set.from_array(new_form).with_meta(meta)
      end
    end

    def evaluate(env, list)
      list = macroexpand(env, list)

      unless list.is_a?(List)
        return list
      end

      if s = special(list)
        return s.call(list, env, *list.cdr)
      end

      head = list.car

      fn = head.evaluate(env)

      if fn.respond_to?(:trace) && (t = fn.trace)
        env = env.bind("__stack__", env["__stack__"].add(t))
      end

      if Var === fn
        fn = fn.deref
      end

      case fn
      when IFn
        args = (list.cdr || []).to_a.map { |elem| elem.evaluate(env) }
        begin
          fn.call *args
        rescue => e
          raise e.class, e.message, (env["__stack__"].to_a.reverse)
        end
      when ::Symbol
        args = (list.cdr || []).to_a.map { |elem| elem.evaluate(env) }
        if args.count > 2
          raise ArgumentError, "more than one arg passed as argument to Keyword #{fn}", env["__stack__"].to_a
        end
        map, default = *args
        if ILookup === map
          map.fetch(fn, default)
        end
      else
        raise Error, "What? #{head.inspect}, #{fn.inspect}, #{list}, #{list.meta}"
      end
    end
  end
end
