# ==============================================================================
# Terraform Outputs
# ==============================================================================

output "project_id" {
  description = "Railway project ID"
  value       = railway_project.app.id
}

output "web_service_id" {
  description = "Railway web service ID"
  value       = railway_service.web.id
}

output "web_domain" {
  description = "Railway-generated domain for the web service"
  value       = railway_service_domain.web.domain
}

output "sidekiq_service_id" {
  description = "Railway Sidekiq worker service ID"
  value       = railway_service.sidekiq.id
}

output "postgres_service_id" {
  description = "Railway PostgreSQL service ID"
  value       = railway_service.postgres.id
}

output "redis_service_id" {
  description = "Railway Redis service ID"
  value       = railway_service.redis.id
}

output "postgres_proxy_port" {
  description = "External TCP proxy port for PostgreSQL"
  value       = railway_tcp_proxy.postgres.proxy_port
}

output "redis_proxy_port" {
  description = "External TCP proxy port for Redis"
  value       = railway_tcp_proxy.redis.proxy_port
}

# ==============================================================================
# Cloudflare Outputs
# ==============================================================================

output "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  value       = data.cloudflare_zone.main.id
}

output "custom_domain" {
  description = "Custom domain (Cloudflare)"
  value       = var.cloudflare_domain
}

output "custom_domain_url" {
  description = "Full URL for the custom domain"
  value       = "https://${var.cloudflare_domain}"
}
