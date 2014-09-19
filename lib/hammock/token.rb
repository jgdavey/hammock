module Hammock
  Token = Struct.new(:name, :token) do
    def inspect; token.inspect; end
    def to_a; token; end
  end

  TokenCollection = Struct.new(:name, :body) do
    def inspect; [name, body].inspect end
    def to_s; inspect; end
    def to_a
      body.map(&:to_a)
    end
  end
end
