Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY", nil)
Stripe.api_version = "2024-12-18.acacia"

# Log Stripe events in development
if Rails.env.development?
  Stripe.log_level = Stripe::LEVEL_INFO
end
