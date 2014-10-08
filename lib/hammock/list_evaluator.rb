require 'hammock/symbol'
module Hammock
  module ListEvaluator
    DOT = Symbol.intern(".")
    extend self

    def namespace(env, sym)
      env["__namespace__"] || sym.ns || RT::CURRENT_NS.deref
    end

    def find_var(env, sym)
      namespace(env, sym).find_var!(sym)
    end

    def macro?(form)
      Meta === form && form.meta && form.meta[:macro]
    end

    def expand_host(form)
      method, target, *args = *form
      args = ConsCell.from_array(args)
      method = Symbol.intern(method.name[1..-1])
      if args
        args = args.cons(method)
      else
        args = method
      end
      ConsCell.from_array [DOT, target, args]
    end

    def macroexpand1(env, form)
      sym = form.car
      if Hammock::Symbol === sym && sym.name.start_with?(DOT.name)
        form = expand_host(form)
        return form, false
      end
      item = find_var(env, sym)
      dreffed = item.deref
      if macro?(item) || macro?(dreffed)
        form = dreffed.call(dreffed, nil, form, env, *form.cdr)
        return form, true
      else
        return form, false
      end
    end

    def special(form)
      RT.special(form.car)
    end

    def macroexpand(env, form)
      ret = true
      spec = nil
      while ret && !spec
        form, ret = macroexpand1(env, form)
        spec = special(form)
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

      if s = special(list)
        return s.call(list, env, *list.cdr)
      end

      head = list.car

      fn = head.evaluate(env)

      if Var === fn
        fn = fn.deref
      end

      if Function === fn
        args = (list.cdr || []).map { |elem| elem.evaluate(env) }
        fn.call list, env, *args
      else
        raise "What? #{fn}"
      end
    end
  end
end
