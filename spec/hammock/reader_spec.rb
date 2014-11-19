# encoding: utf-8
require 'hammock/reader'
require 'stringio'

describe Hammock::Reader do
  def read_string(string)
    io = StringIO.new(string)
    Hammock::Reader.new.read(io)
  end

  it "reads a list of numbers" do
    result = read_string "(1 21 331)"
    expect(result.to_a).to eq [1, 21, 331]
  end

  it "reads nested lists of numbers" do
    result = read_string "(1 (21 331))"
    expect(result.to_a).to eq [1, Hammock::Sequence.from_array([21, 331])]
  end

  it "reads bare numbers" do
    result = read_string "324"
    expect(result).to eq 324
  end

  it "reads floats" do
    result = read_string "3.24"
    expect(result).to eq 3.24
  end

  it "reads negative numbers" do
    result = read_string "-3.24"
    expect(result).to be_a Numeric
    expect(result).to eq -3.24
  end

  it "reads symbols prefixed with -" do
    result = read_string "-foo"
    expect(result).to eq Hammock::Symbol.intern("-foo")
  end

  it "reads strings" do
    result = read_string '"Hello"'
    expect(result).to eq "Hello"
  end

  it "reads strings with escaped double quotes" do
    result = read_string '"Hello \"Mate\""'
    expect(result).to eq 'Hello "Mate"'
  end

  it "reads strings with escapes" do
    result = read_string '"Hello \\\\"'
    expect(result).to eq 'Hello \\'
  end

  it "reads strings with newlines" do
    result = read_string '"Hello\nThere"'
    expect(result).to eq "Hello\nThere"
  end

  it "reads strings with unicode escape sequences" do
    result = read_string '"Hello snowman \u2603"'
    expect(result).to eq "Hello snowman ☃"
  end

  it "reads character literals" do
    result = read_string '[\u2603]'
    expect(result.to_a.first).to eq "☃"
  end

  it "reads character literal newlines" do
    result = read_string '[\newline]'
    expect(result.to_a.first).to eq "\n"
  end

  it "reads lists with strings and numbers" do
    result = read_string '(1.2 ("Foo" 3))'
    expect(result.to_a).to eq [1.2, Hammock::Sequence.from_array(["Foo", 3])]
  end

  it "reads vectors" do
    result = read_string '["foo" ["bar"]]'
    expect(result.to_a).to eq ["foo", Hammock::Vector.from_array(["bar"])]
  end

  it "reads maps" do
    result = read_string '{"key" "value"}'
    expect(result).to eq Hammock::Map.from_array ["key", "value"]
  end

  it "reads nested maps" do
    result = read_string '{"key1" {"key2" "value"}}'
    expect(result).to eq Hammock::Map.from_array(["key1", Hammock::Map.from_array(["key2", "value"])])
  end

  it "ignores optional commas" do
    result = read_string '{"key1" "val", "key2", "val"}'
    expect(result).to eq Hammock::Map.from_array ["key1", "val", "key2", "val"]
  end

  it "parses basic keywords" do
    result = read_string ':foo'
    expect(result).to eq :foo
  end

  it "parses namespaced keywords" do
    result = read_string ':foo/bar'
    expect(result).to eq :"foo/bar"
  end

  it "parses implicitly namespaced keywords" do
    result = read_string '::foo'
    expect(result).to eq :"clojure.core/foo"
  end

  it "parses complex nested data structures" do

    result = read_string '{:foo [1 2 3]
                           :bar "Baz"
                           :quux {:a 1 :b 2}}'
    expect(result).to eq Hammock::Map.from_array([:foo,
                                                  Hammock::Vector.from_array([1,2,3]),
                                                  :bar, "Baz",
                                                  :quux,
                                                  Hammock::Map.from_array([:a, 1, :b, 2])])
  end

  it "parses character literals" do
    result = read_string '\\a'
    expect(result).to eq "a"
  end

  it "parses nil, true, and false" do
    result = read_string '[true false nil]'
    expect(result.to_a).to eq [true, false, nil]
  end

  it "ignores line-ending comments" do
    result = read_string '["foo" ; ignore me
                           "bar"] ; me too'
    expect(result.to_a).to eq ["foo", "bar"]
  end

  it "reads set literals" do
    result = read_string '#{1 2 3}'
    expect(result).to eq Hammock::Set.from_array([1, 2, 3])
  end

  it "reads regex literals" do
    str = '#"[\\\\d]+"'
    result = read_string str
    expect(result).to eq Regexp.new "[\\d]+"
  end

  it "reads symbols" do
    str = '(map foo)'
    result = read_string str
    expect(result).to eq Hammock::Sequence.from_array [
      Hammock::Symbol.intern("map"),
      Hammock::Symbol.intern("foo")]
  end

  it "reads symbols with ticks too" do
    str = "(map' foo)"
    result = read_string str
    expect(result).to eq Hammock::Sequence.from_array [
      Hammock::Symbol.intern("map'"),
      Hammock::Symbol.intern("foo")]
  end

  it "reads Ruby constants" do
    str = 'Object'
    result = read_string str
    expect(result).to eq Hammock::Symbol.intern("Object")
  end

  it "reads quoted symbols" do
    str = "'foo"
    result = read_string str
    expect(result).to eq Hammock::Sequence.from_array [Hammock::Symbol.intern("quote"), Hammock::Symbol.intern("foo")]
  end

  it "reads quoted lists" do
    str = "'(foo bar)"
    result = read_string str
    expected = Hammock::Sequence.from_array([Hammock::Symbol.intern("quote"), Hammock::Sequence.from_array([Hammock::Symbol.intern("foo"), Hammock::Symbol.intern("bar")])])
    expect(result).to eq expected
  end

  it "assigns metadata to the following form" do
    str = "^{:foo true} [1 2]"
    result = read_string str
    expected_meta = Hammock::Map.from_array [:foo, true]
    expect(result.meta).to eq expected_meta
  end

  it "assigns keyword metadata" do
    str = "^:foo [1 2]"
    result = read_string str
    expected_meta = Hammock::Map.from_array [:foo, true]
    expect(result.meta).to eq expected_meta
  end

  it "assigns keyword metadata" do
    str = "^:foo ^:bar [1 2]"
    result = read_string str
    expected_meta = Hammock::Map.from_array [:foo, true, :bar, true]
    expect(result.meta).to eq expected_meta
  end

  it "raises error when attempting to apply meta-data to non-meta-data objects" do
    str = '^:foo ^:bar "hello"'
    expect { read_string(str) }.to raise_error
  end

  it "reads syntax quoted clojure.core things" do
    form = read_string("(def foo 1)")
    Hammock::Compiler.evaluate(Hammock::RT.global_env, form)
    str = '`foo'
    result = read_string(str)
    expected = Hammock::Symbol.intern("clojure.core", "foo")
    expect(result.tail.first).to eq expected
  end

  it "reads unquotes" do
    str = '`~blah'
    result = read_string(str)
    expected = Hammock::Symbol.intern("blah")
    expect(result).to eq expected
  end

  it "reads from a file" do
    reader = Hammock::Reader.new
    result = nil
    File.open(File.expand_path("../../examples/data.hmk", __FILE__)) do |f|
      result = reader.read(f)
    end
    expect(result.to_a).to eq [Hammock::Symbol.intern("map"),
                               Hammock::Symbol.intern("foo"),
                               Hammock::Map.from_array([:foo, "bar", :bar, 1, :quux, 1.4])]
  end
end
