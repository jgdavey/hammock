require 'hammock/rt'

describe Hammock::RT do
  describe ".resolve_path" do
    it "finds this file" do
      path = Hammock::RT.resolve_path("hammock/rt_spec.rb")
      expect(path).to eq(Pathname.new(__FILE__))
    end
  end
end
