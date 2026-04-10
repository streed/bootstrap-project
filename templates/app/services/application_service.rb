# Base service class using dry-monads for railway-oriented programming.
#
# All service objects inherit from this class and implement #call.
# Services return Success/Failure monads for composable error handling.
#
# Usage:
#   class Users::CreateService < ApplicationService
#     option :name, type: Types::Strict::String
#     option :email, type: Types::Strict::String
#
#     def call
#       validation = validate(name:, email:)
#       return Failure(validation.errors.to_h) if validation.failure?
#
#       user = User.create!(name:, email:)
#       Success(user)
#     rescue ActiveRecord::RecordInvalid => e
#       Failure(e.record.errors.full_messages)
#     end
#   end
#
#   result = Users::CreateService.call(name: "Jane", email: "jane@example.com")
#   if result.success?
#     redirect_to result.value!
#   else
#     flash[:alert] = result.failure
#   end
#
class ApplicationService
  extend Dry::Initializer
  include Dry::Monads[:result, :do, :try]

  def self.call(**args)
    new(**args).call
  end

  def call
    raise NotImplementedError, "#{self.class}#call must be implemented"
  end
end
