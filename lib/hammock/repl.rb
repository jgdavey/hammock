require 'hammock'
require 'hammock/rt'
require 'readline'
require 'stringio'

module Hammock
  class REPL
    def self.start
      new.start
    end

    def start
      Hammock::RT.bootstrap!
      reader = Hammock::Reader.new

      while line = Readline.readline('> ', true)
        begin
          line = StringIO.new(line)
          unless line.string.casecmp("exit") == 0
            p Hammock::RT.compile_and_eval(reader.read(line))
          else
            puts "Bye for now"
            break
          end
        rescue Exception => ex
          puts "ERROR: #{ex.class} #{ex}"
          puts ex.backtrace
        end
      end

      exit
    end
  end
end
