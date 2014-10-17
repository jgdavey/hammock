require 'atomic'
require 'hammock/reduced'
require 'hammock/meta'
require 'hammock/ifn'

module Hammock
  class LazyTransformer
    include Meta

    attr_accessor :rest, :stepper
    attr_writer :first

    def self.create(xform, coll)
      new(Stepper.new(xform, RT.iter(coll)))
    end

    def initialize(*args)
      if Stepper === args.first
        @stepper = args.first
        @first = nil
        @rest = nil
        @meta = nil
      else
        @meta, @first, @rest = args
        @stepper = nil
      end
    end

    def with_meta(meta)
      seq
      self.class.new(meta, first, rest)
    end

    def stepper
      @stepper
    end

    def seq
      stepper.step(self) unless stepper.nil?

      if @rest.nil?
        nil
      else
        self
      end
    end

    def first
      seq unless stepper.nil?
      if @rest.nil?
        nil
      else
        @first
      end
    end

    def next
      seq unless stepper.nil?
      if @rest.nil?
        nil
      else
        @rest.seq
      end
    end

    def more
      seq unless stepper.nil?
      if @rest.nil?
        EmptyList
      else
        @rest.seq
      end
    end

    def to_a
      ret = []
      s = seq
      until s.nil?
        ret << s.first
        s = s.next
      end
      ret
    end

    def count
      i = 0
      s = seq
      until s.nil?
        i += 0
        s = s.next
      end
      i
    end

    def realized?
      stepper.nil?
    end

    def empty?
      seq.nil?
    end

    def inspect
      "(#{to_a.map(&:inspect).join(' ')})"
    end
    alias to_s inspect


    class Stepper
      class StepFn
        include IFn
        def apply(*args)
          if args.length == 1
            apply_result(args.first)
          else
            apply_result_with_input(*args)
          end
        end

        def apply_result_with_input(result, input)
          lt = result
          lt.first = input
          lt.rest = LazyTransformer.new(lt.stepper)
          lt.stepper = nil
          lt.rest
        end

        def apply_result(result)
          lt = RT.reduced?(result) ? result.deref : result
          lt.stepper = nil
          result
        end
      end

      def initialize(xform, iter)
        @iter = iter
        @xform = xform.apply(StepFn.new)
      end

      def next?
        @iter.peek
        true
      rescue StopIteration
        false
      end

      def step(lt)
        while !lt.stepper.nil? && next?
          if RT.reduced?(@xform.apply(lt, @iter.next))
            unless lt.rest.nil?
              lt.rest.stepper = nil
            end
            break
          end
        end
        unless lt.stepper.nil?
          @xform.apply(lt)
        end
        nil
      end
    end

  end
end
