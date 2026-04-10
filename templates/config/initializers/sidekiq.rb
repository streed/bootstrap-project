Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
    network_timeout: 5,
    pool_timeout: 5
  }

  config.concurrency = ENV.fetch("SIDEKIQ_CONCURRENCY", 5).to_i
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
    network_timeout: 5,
    pool_timeout: 5
  }
end
