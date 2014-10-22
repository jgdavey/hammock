require 'hammock/symbol'
module Hammock
  module ListEvaluator
    CompileError = Class.new(StandardError)
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
      method, target, *args = *form
      args = Sequence.from_array(args)
      method = Symbol.intern(method.name[1..-1])
      if args
        args = args.cons(method)
      else
        args = method
      end
      Sequence.from_array [DOT, target, args]
    end

    def expand_new(form)
      klass, *args = *form
      args = Sequence.from_array(args)
      klass = Symbol.intern(klass.name[0..-2])
      if args
        args = args.cons(NEW)
      else
        args = NEW
      end
      Sequence.from_array [DOT, klass, args]
    end

    def macroexpand1(form, env=RT.global_env)
      form, _ = _macroexpand1(env, form)
      form
    end

    def _macroexpand1(env, form)
      return form, false unless form.is_a?(List)
      sym = form.car
      return form, false unless Hammock::Symbol === sym

      if item = find_var(env, sym)
        dreffed = item.deref
        if macro?(item) || macro?(dreffed)
          begin
            form = dreffed.call(form, env, *form.cdr)
          rescue => e
            raise CompileError, "Problem expanding macro: #{form.meta}, #{form.inspect}. Error: #{e}"
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

      if Var === fn
        fn = fn.deref
      end

      case fn
      when IFn
        args = (list.cdr || []).to_a.map { |elem| elem.evaluate(env) }
        fn.call *args
      when ::Symbol
        args = (list.cdr || []).to_a.map { |elem| elem.evaluate(env) }
        if args.count > 2
          raise ArgumentError, "more than one arg passed as argument to Keyword #{fn}"
        end
        map, default = *args
        if ILookup === map
          map.fetch(fn, default)
        end
      else
        raise "What? #{fn}, #{fn.class}"
      end
    end
  end
end
