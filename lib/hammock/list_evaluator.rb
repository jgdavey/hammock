module Hammock
  module ListEvaluator
    def self.macro_expand(env, cons_cell)
      cons_cell
    end

    def self.evaluate(env, cons_cell)
      list = macro_expand(env, cons_cell)

      head = list.car

      if special = RT.special(head)
        return special.call(env, *list.cdr)
      end

      fn = head.evaluate(env)
      if Function === fn
        args = (list.cdr || []).map { |elem| elem.evaluate(env) }
        fn.call env, *args
      else
        raise "What? #{fn}"
      end
    end
  end
end
