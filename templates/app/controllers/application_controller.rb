class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!

  after_action :verify_authorized, except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore

    flash[:alert] = t("pundit.#{policy_name}.#{exception.query}",
                       default: "You are not authorized to perform this action.")

    redirect_back(fallback_location: root_path)
  end

  def skip_pundit?
    devise_controller? || self.class == HealthController
  end
end
