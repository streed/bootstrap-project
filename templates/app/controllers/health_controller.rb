class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  # GET /health
  def show
    render json: {
      status: "ok",
      timestamp: Time.current.iso8601,
      version: Rails.application.config.respond_to?(:version) ? Rails.application.config.version : "0.1.0",
      rails: Rails.version,
      ruby: RUBY_VERSION
    }
  end

  # GET /health/db
  def database
    ActiveRecord::Base.connection.execute("SELECT 1")
    render json: {
      status: "ok",
      service: "postgresql",
      timestamp: Time.current.iso8601
    }
  rescue StandardError => e
    render json: {
      status: "error",
      service: "postgresql",
      message: e.message,
      timestamp: Time.current.iso8601
    }, status: :service_unavailable
  end

  # GET /health/redis
  def redis
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    redis.ping
    render json: {
      status: "ok",
      service: "redis",
      timestamp: Time.current.iso8601
    }
  rescue StandardError => e
    render json: {
      status: "error",
      service: "redis",
      message: e.message,
      timestamp: Time.current.iso8601
    }, status: :service_unavailable
  end
end
