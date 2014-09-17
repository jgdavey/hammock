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
    expect(result.to_a).to eq [1, [21, 331]]
  end

  it "reads bare numbers" do
    result = read_string "324"
    expect(result.to_a).to eq 324
  end

  it "reads floats" do
    result = read_string "3.24"
    expect(result.to_a).to eq 3.24
  end

  it "reads strings" do
    result = read_string '"Hello"'
    expect(result.to_a).to eq "Hello"
  end

  it "reads strings with escaped double quotes" do
    result = read_string '"Hello \"Mate\""'
    expect(result.to_a).to eq 'Hello "Mate"'
  end

  it "reads strings with escapes" do
    result = read_string '"Hello \\\\"'
    expect(result.to_a).to eq 'Hello \\'
  end

  it "reads strings with newlines" do
    result = read_string '"Hello\nThere"'
    expect(result.to_a).to eq "Hello\nThere"
  end

  it "reads strings with unicode escape sequences" do
    result = read_string '"Hello snowman \u2603"'
    expect(result.to_a).to eq "Hello snowman ☃"
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
    expect(result.to_a).to eq [1.2, ["Foo", 3]]
  end

  it "reads vectors" do
    result = read_string '["foo" ["bar"]]'
    expect(result.to_a).to eq ["foo", ["bar"]]
  end

  it "reads maps" do
    result = read_string '{"key" "value"}'
    expect(result.to_a).to eq ["key", "value"]
  end

  it "reads nested maps" do
    result = read_string '{"key1" {"key2" "value"}}'
    expect(result.to_a).to eq ["key1", ["key2", "value"]]
  end

  it "ignores optional commas" do
    result = read_string '{"key1" "val", "key2", "val"}'
    expect(result.to_a).to eq ["key1", "val", "key2", "val"]
  end

  it "parses basic keywords" do
    result = read_string ':foo'
    expect(result.to_a).to eq :foo
  end

  it "parses namespaced keywords" do
    result = read_string ':foo/bar'
    expect(result.to_a).to eq :"foo/bar"
  end

  it "parses implicitly namespaced keywords" do
    result = read_string '::foo'
    expect(result.to_a).to eq :":foo"
  end

  it "parses complex nested data structures" do

    result = read_string '{:foo [1 2 3]
                           :bar "Baz"
                           :quux {:a 1 :b 2}}'
    expect(result.to_a).to eq [:foo, [1,2,3], :bar, "Baz", :quux, [:a, 1, :b, 2]]
  end

  it "parses character literals" do
    result = read_string '\\a'
    expect(result.to_a).to eq "a"
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
    expect(result.inspect).to eq [:SET, [1, 2, 3]].inspect
  end

  it "reads regex literals" do
    str = '#"[\\\\d]+"'
    result = read_string  str
    expect(result.name).to eq :REGEX
    expect(result.token).to eq "[\\d]+"
  end

  it "reads from a file" do
    reader = Hammock::Reader.new
    result = nil
    File.open(File.expand_path("../../examples/data.hmk", __FILE__)) do |f|
      result = reader.read(f)
    end
    expect(result.to_a).to eq ["map", "foo", [:foo, "bar", :bar, 1, :quux, 1.4]]
  end
end
