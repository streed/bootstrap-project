# Example service demonstrating dry-monads + dry-validation patterns.
# Delete this file once you have your own services.
#
# Usage:
#   result = ExampleService.call(name: "Rails", count: 3)
#   result.success? # => true
#   result.value!   # => "Hello, Rails! (repeated 3 times)"
#
class ExampleService < ApplicationService
  option :name,  type: Types::Strict::String
  option :count, type: Types::Strict::Integer, default: -> { 1 }

  class Contract < Dry::Validation::Contract
    params do
      required(:name).filled(:string, min_size?: 1)
      required(:count).filled(:integer, gt?: 0, lteq?: 100)
    end
  end

  def call
    validation = Contract.new.call(name:, count:)
    return Failure(validation.errors.to_h) if validation.failure?

    message = (["Hello, #{name}!"] * count).join(" ")
    Success(message)
  end
end
