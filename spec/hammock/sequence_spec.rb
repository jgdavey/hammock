require 'hammock/sequence'

describe Hammock::Sequence do
  describe '::from_array' do
    it 'when empty is empty' do
      empty = described_class.from_array([])
      expect(empty).to eq(Hammock::EmptyList)
      expect(empty.count).to eq(0)
      expect(empty.to_a).to eq([])
    end

    it 'turns array of one into list of one' do
      list = described_class.from_array([1])
      expect(list).to be_a Hammock::Sequence
      expect(list.to_a).to eq([1])
    end

    it 'turns an array of stuff into a linked list of that stuff' do
      list = described_class.from_array([1, 2, 3])
      expect(list.count).to eq(3)
      expect(list.to_a).to eq [1, 2, 3]
    end
  end
end
