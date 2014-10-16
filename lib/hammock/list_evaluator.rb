require 'hammock/symbol'
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

    def macroexpand1(env, form)
      return form, false unless form.is_a?(List)
      sym = form.car
      if Hammock::Symbol === sym
        if sym.name.start_with?(DOT.name)
          form = expand_method(form)
          return form, false
        elsif sym.name.end_with?(DOT.name)
          form = expand_new(form)
          return form, false
        end
      end
      if item = find_var(env, sym)
        dreffed = item.deref
        if macro?(item) || macro?(dreffed)
          form = dreffed.call(dreffed, nil, form, env, *form.cdr)
          return form, true
        else
          return form, false
        end
      else
        return form, false
      end
    end

    def special(form)
      return unless form.is_a?(List)
      RT.special(form.car)
    end

    def macroexpand(env, form)
      ret = true
      spec = nil
      while ret && !spec
        form, ret = macroexpand1(env, form)
        spec = special(form) if form
      end
      form
    end

    def evaluate(env, list)
      if s = special(list)
        return s.call(list, env, *list.cdr)
      end

      if Hammock::Symbol === list.car
        list = macroexpand(env, list)
      end

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
      when Function
        args = (list.cdr || []).to_a.map { |elem| elem.evaluate(env) }
        fn.call list, env, *args
      when ::Symbol
        args = (list.cdr || []).to_a.map { |elem| elem.evaluate(env) }
        if args.count > 2
          raise ArgumentError, "more than one arg passed as argument to Keyword #{fn}"
        end
        map, default = *args
        map.fetch(fn, default) if map
      when Map, Vector
        args = (list.cdr || []).to_a.map { |elem| elem.evaluate(env) }
        if args.count > 2
          raise ArgumentError, "more than one arg passed as argument to Map"
        end
        key, default = *args
        fn.fetch(key, default)
      else
        raise "What? #{fn}, #{fn.class}"
      end
    end
  end
end
