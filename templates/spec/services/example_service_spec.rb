require "rails_helper"

RSpec.describe ExampleService do
  describe ".call" do
    context "with valid params" do
      it "returns a Success monad" do
        result = described_class.call(name: "Rails", count: 1)
        expect(result).to be_success
      end

      it "returns the greeting message" do
        result = described_class.call(name: "Rails", count: 1)
        expect(result.value!).to eq("Hello, Rails!")
      end

      it "repeats the message based on count" do
        result = described_class.call(name: "World", count: 3)
        expect(result.value!).to eq("Hello, World! Hello, World! Hello, World!")
      end

      it "defaults count to 1" do
        result = described_class.call(name: "Test")
        expect(result.value!).to eq("Hello, Test!")
      end
    end

    context "with invalid params" do
      it "returns a Failure for an empty name" do
        result = described_class.call(name: "", count: 1)
        expect(result).to be_failure
        expect(result.failure).to have_key(:name)
      end

      it "returns a Failure for count of 0" do
        result = described_class.call(name: "Test", count: 0)
        expect(result).to be_failure
        expect(result.failure).to have_key(:count)
      end

      it "returns a Failure for count over 100" do
        result = described_class.call(name: "Test", count: 101)
        expect(result).to be_failure
        expect(result.failure).to have_key(:count)
      end

      it "returns a Failure for negative count" do
        result = described_class.call(name: "Test", count: -1)
        expect(result).to be_failure
        expect(result.failure).to have_key(:count)
      end
    end
  end

  describe "Contract" do
    subject(:contract) { described_class::Contract.new }

    it "validates a correct input" do
      result = contract.call(name: "Rails", count: 5)
      expect(result).to be_success
    end

    it "rejects missing name" do
      result = contract.call(name: nil, count: 1)
      expect(result).to be_failure
    end

    it "rejects missing count" do
      result = contract.call(name: "Rails", count: nil)
      expect(result).to be_failure
    end
  end
end
