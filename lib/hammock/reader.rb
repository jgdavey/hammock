require 'delegate'
require 'hammock/meta'
require 'hammock/map'
require 'hammock/rt'
require 'hammock/set'
require 'hammock/sequence'
require 'hammock/symbol'
require 'hammock/vector'

module Hammock
  class Reader
    class LineNumberingIO < SimpleDelegator
      attr_reader :line_number, :column_number, :filename

      NEWLINE = $/ # line sep

      def initialize(io)
        @column_number = 0
        @line_number = 1
        @filename = if File === io
                      File.absolute_path(io)
                    else
                      "(input)"
                    end
        super
      end

      def getc
        @column_number += 1
        char = __getobj__.getc
        if char == NEWLINE
          @line_number += 1
          @last_line_length = @column_number
          @column_number = 0
        end
        char
      end

      def ungetc(char)
        __getobj__.ungetc(char)
        if char == NEWLINE
          @line_number -= 1
          @column_number = @last_line_length
        end
      end
    end

    TOKENS = {
      "true" => true,
      "false" => false,
      "nil" => nil
    }

    # SYMBOL_PATTERN = Regexp.new("^:?([^/0-9].*/)?(/|[^/0-9][^/]*)$")
    UNQUOTE = Symbol.intern("clojure.core", "unquote")
    UNQUOTE_SPLICING = Symbol.intern("clojure.core", "unquote-splicing")
    APPLY = Symbol.intern("clojure.core", "apply")
    DEREF = Symbol.intern("clojure.core", "deref")
    SEQ = Symbol.intern("clojure.core", "seq")
    CONCAT = Symbol.intern("clojure.core", "concat")
    LIST = Symbol.intern("list")
    QUOTE = Symbol.intern("quote")
    AMP = Symbol.intern("&")
    VECTOR = Symbol.intern("clojure.core", "vector")
    HASHMAP = Symbol.intern("clojure.core", "hash-map")
    HASHSET = Symbol.intern("clojure.core", "hash-set")
    FN = Symbol.intern("clojure.core", "fn")

    MACROS = {
      ?( => :read_list,
      ?) => :read_rparen,
      ?[ => :read_vector,
      ?] => :read_rbracket,
      ?{ => :read_map,
      ?} => :read_rbrace,
      ?: => :read_keyword,
      ?" => :read_string,
      ?; => :read_comment,
      ?# => :read_dispatched,
      ?% => :read_arg,
      ?' => :read_quoted,
      ?@ => :read_deref,
      ?` => :read_syntax_quoted,
      ?^ => :read_meta,
      ?~ => :read_unquote,
    "\\" => :read_char
    }

    DISPATCH_MACROS = {
      ?{ => :read_set,
      ?" => :read_regex,
      ?^ => :read_meta,
      ?( => :read_function,
      ?' => :read_var
    }

    HEXCHARS = "0123456789ABCDEF".split("")
    THE_VAR = Symbol.intern("var")

    def whitespace?(char)
      char == " " || char == "\n" || char == "\t" || char == ","
    end

    def macro?(char)
      MACROS.has_key? char
    end

    def terminating_macro?(char)
      macro?(char) && char != ?# && char != ?' && char != ?%
    end

    def ensure_line_numbering(io)
      if LineNumberingIO === io
        io
      else
        LineNumberingIO.new io
      end
    end

    def read_all(io)
      io = ensure_line_numbering(io)
      yield read(io) until io.eof?
    end

    def read(io)
      io = ensure_line_numbering(io)
      until io.eof?
        char = io.getc
        while whitespace?(char)
          char = io.getc
        end

        raise "Unexpected EOF at line #{io.line_number}" unless char

        if char.match(/\d/)
          break read_number(io, char)
        end

        if m = MACROS[char]
          ret = send(m, io, char)
          next if ret == io
          break ret
        else
          token = read_token(io, char)
          break interpret_token(token)
        end

        break if io.eof?
      end
    end

    def interpret_token(token)
      TOKENS.fetch(token) { Symbol.intern(token) }
    end

    def read_list(io, char)
      meta = Map.from_hash(line: io.line_number, column: io.column_number, file: io.filename)
      list = read_delimited_list(")", io)
      Sequence.from_array(list).with_meta(meta)
    end

    def read_vector(io, char)
      vec = read_delimited_list("]", io)
      Vector.from_array vec
    end

    def read_map(io, char)
      map = read_delimited_list("}", io)
      Map.from_array map
    end

    def read_set(io, char)
      set = read_delimited_list("}", io)
      Set.from_array set
    end

    def read_delimited_list(delimiter, io)
      a = []

      loop do
        char = io.getc
        while whitespace?(char)
          char = io.getc
        end

        raise "Unexpected EOF at line #{io.line_number}" unless char

        break if char == delimiter

        if m = MACROS[char]
          ret = send(m, io, char)
          if ret && ret != io
            a << ret
          end
        else
          io.ungetc(char)
          a << read(io)
        end
      end

      a
    end

    def read_rparen(io, char)
      raise "Unexpected ) at line #{io.line_number}"
    end

    def read_keyword(io, colon)
      keyword = ""
      char = io.getc
      if char == ":"
        prefix = RT::CURRENT_NS.deref.name
        keyword << prefix << "/"
      else
        io.ungetc(char)
      end

      loop do
        char = io.getc
        if whitespace?(char) || terminating_macro?(char) || !char
          io.ungetc(char)
          break
        end
        keyword << char
      end
      keyword.to_sym
    end

    def read_stringish(io, open_quote)
      str = ""
      loop do
        char = io.getc
        if !char
          io.ungetc(char)
          break
        end

        break if char == '"'

        if char == "\\"
          char = io.getc
          case char
          when ?t
            char = "\t"
          when ?r
            char = "\r"
          when ?n
            char = "\n"
          when ?b
            char = "\b"
          when ?f
            char = "\f"
          when ?u
            char = io.getc
            unless HEXCHARS.include?(char)
              raise "Expected only hex characters in unicode escape sequence: line #{io.line_number}"
            end
            char = read_unicode_char(io, char)
          end
        end

        str << char
      end
      str
    end

    def read_unicode_char(io, char)
      digits = char
      loop do
        char = io.getc

        if !char
          io.ungetc(char)
          break
        end

        break unless HEXCHARS.include?(char)
        digits << char
      end

      interpret_unicode_char(digits)
    end

    def interpret_unicode_char(digits)
      [digits.hex].pack "U"
    end

    def read_string(io, open_quote)
      str = read_stringish(io, open_quote)
      str
    end

    def read_regex(io, open_quote)
      str = read_stringish(io, open_quote)
      Regexp.new(str)
    end

    def read_char(io, escape)
      char = io.getc
      c = read_token(io, char)
      char = case c
      when "newline"   then "\n"
      when "space"     then " "
      when "tab"       then "\t"
      when "backspace" then "\b"
      when "formfeed"  then "\f"
      when "return"    then "\r"
      when /^u/
        interpret_unicode_char(c[1..-1])
      else
        c
      end

      char
    end

    def read_comment(io, char)
      while char && char != "\n" do
        char = io.getc
      end
    end

    def read_dispatched(io, _)
      char = io.getc
      unless char
        raise "Unexpected EOF at line #{io.line_number}" unless char
      end

      method = DISPATCH_MACROS.fetch(char)
      send(method, io, char)
    end

    def read_number(io, char)
      digits = read_token(io, char)
      match_number(digits) or raise "Unable to parse number: #{digits} at line #{io.line_number}"
    end

    def match_number(digits)
      case digits
      when /^[\d]+$/
        digits.to_i
      when /^\d+\.\d+$/
        digits.to_f
      when /^\d+\/\d+$/
        digits.to_r
      end
    end

    def read_quoted(io, quote_mark)
      read_wrapped(io, QUOTE)
    end

    def read_deref(io, at)
      read_wrapped(io, DEREF)
    end

    def read_wrapped(io, sym)
      RT.list(sym, read(io))
    end

    def read_unquote(io, quote_mark)
      char = io.getc
      if char == "@"
        ret = read(io)
        RT.list(UNQUOTE_SPLICING, ret)
      else
        io.ungetc(char)
        ret = read(io)
        RT.list(UNQUOTE, ret)
      end
    end

    def read_syntax_quoted(io, quote_mark)
      form = read(io)
      Thread.current[:gensym_env] = Map.new
      syntax_quote(form)
    ensure
      Thread.current[:gensym_env] = nil
    end

    def syntax_quote(form)
      ret = nil
      return unless form
      if RT.special(form)
        ret = RT.list(QUOTE, form)
      elsif Hammock::Symbol === form
        sym = form
        if !sym.ns && sym.name.end_with?("#")
          unless map = Thread.current[:gensym_env]
            raise "Gensym literal not in syntax-quote"
          end
          unless gs = map[sym.name]
            gs = Symbol.intern(nil, sym.name[0..-2] + "__#{RT.next_id}__auto__")
            Thread.current[:gensym_env] = map.assoc(sym.name, gs)
          end
          sym = gs
        else
          ns = RT::CURRENT_NS.deref
          lookup = ns.find_var(sym.name)
          if lookup
            sym = Hammock::Symbol.intern(ns.name, sym.name)
          else
            sym
          end
        end
        ret = RT.list(QUOTE, sym)
      elsif form.respond_to?(:first)
        if form.first == UNQUOTE
          ret = form.cdr.car
        elsif form.first == UNQUOTE_SPLICING
          raise "This is a problem"
        elsif Map === form
          ret = RT.list(APPLY, HASHMAP, RT.list(SEQ, RT.cons(CONCAT, syntax_quote_expand_list(form))))
        elsif Hammock::Set === form
          ret = RT.list(APPLY, HASHSET, RT.list(SEQ, RT.cons(CONCAT, syntax_quote_expand_list(form))))
        elsif Vector === form
          ret = RT.list(APPLY, VECTOR, RT.list(SEQ, RT.cons(CONCAT, syntax_quote_expand_list(form))))
        elsif Hammock::List === form
          seq = RT.seq(form)
          if seq
            ret = RT.list(SEQ, RT.cons(CONCAT, syntax_quote_expand_list(seq)))
          else
            ret = RT.cons(Hammock::Symbol.intern("list"), nil)
          end
        end
      elsif String === form || Numeric === form || ::Symbol === form
        ret = form
      else
        ret = RT.list(QUOTE, form)
      end
      ret
    end


    def unquote?(form)
      Hammock::List === form && (UNQUOTE == RT.first(form))
    end

    def unquote_splicing?(form)
      Hammock::List === form && (UNQUOTE_SPLICING == RT.first(form))
    end

    def syntax_quote_expand_list(seq)
      ret = Vector.new
      seq = RT.seq(seq)
      while !seq.empty?
        item = seq.first
        if unquote?(item)
          ret = ret.cons(RT.list(LIST, RT.second(item)))
        elsif unquote_splicing?(item)
          ret = ret.cons(RT.second(item))
        else
          ret = ret.cons(RT.list(LIST, syntax_quote(item)))
        end
        seq = seq.cdr
      end
      RT.seq(ret)
    end

    def read_var(io, quote_mark)
      Hammock::Sequence.from_array [THE_VAR, read(io)]
    end

    def read_function(io, paren)
      Thread.current[:arg_env] = Map.new
      io.ungetc(paren)
      form = read(io)
      args = Vector.new
      argsyms = Thread.current[:arg_env]
      keys = argsyms.keys.to_a
      unless argsyms.empty?
        higharg = keys.last
        if higharg > 0
          (1..higharg).each do |i|
            sym = argsyms[i] || garg(i)
            args = args.cons(sym)
          end
        end

        if restsym = argsyms[-1]
          args = args.cons(AMP)
          args = args.cons(restsym)
        end
      end
      RT.list(FN, args, form)
    ensure
      Thread.current[:arg_env] = nil
    end

    def read_meta(io, hat)
      meta = read(io)
      if ::Symbol === meta
        meta = Map.from_array [meta, true]
      end
      following = read(io)

      unless Meta === following
        raise "#{following.inspect} does not implement metadata"
      end

      if following.meta
        meta = following.meta.merge(meta)
      end

      following.with_meta(meta)
    end

    def read_token(io, initch)
      chars = initch.dup
      loop do
        char = io.getc
        if !char || whitespace?(char) || terminating_macro?(char)
          io.ungetc(char)
          break
        end
        chars << char
      end
      chars
    end

    def garg(n)
      Symbol.intern (n == -1 ? "rest" : "p#{n}") + "__#{RT.next_id}#"
    end

    def register_arg(n)
      argsyms = Thread.current[:arg_env]
      if(!argsyms)
        raise ArgumentError, "arg literal not in #()"
      end
      unless ret = argsyms[n]
        ret = garg(n)
        Thread.current[:arg_env] = argsyms.assoc(n, ret)
      end
      ret
    end

    def read_arg(io, pct)
      unless Thread.current[:arg_env]
        return interpret_token(read_token(io, '%'))
      end
      char = io.getc
      io.ungetc(char)

      # % alone is first arg
      if whitespace?(char) || terminating_macro?(char)
        return register_arg(1)
      end
      n = read(io)
      if n == AMP
        return register_arg(-1)
      elsif Integer === n
        register_arg(n)
      else
        raise ArgumentError, "arg literal must be %, %& or %integer"
      end
    end

  end
end
