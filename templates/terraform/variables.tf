# ==============================================================================
# Railway Configuration
# ==============================================================================

variable "railway_api_token" {
  description = "Railway API token (from https://railway.com/account/tokens)"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Name of the Railway project"
  type        = string
  default     = "my-rails-app"
}

# ==============================================================================
# Application Configuration
# ==============================================================================

variable "rails_env" {
  description = "Rails environment"
  type        = string
  default     = "production"
}

variable "rails_master_key" {
  description = "Rails master key for credentials decryption"
  type        = string
  sensitive   = true
}

variable "secret_key_base" {
  description = "Rails secret key base (generate with: rails secret)"
  type        = string
  sensitive   = true
}

# ==============================================================================
# Docker Image
# ==============================================================================

variable "docker_image" {
  description = "Docker image for the Rails application (e.g., ghcr.io/org/app:latest)"
  type        = string
}

variable "docker_registry_username" {
  description = "Docker registry username (for private registries)"
  type        = string
  default     = ""
}

variable "docker_registry_password" {
  description = "Docker registry password (for private registries)"
  type        = string
  sensitive   = true
  default     = ""
}

# ==============================================================================
# Stripe
# ==============================================================================

variable "stripe_publishable_key" {
  description = "Stripe publishable key"
  type        = string
  default     = ""
}

variable "stripe_secret_key" {
  description = "Stripe secret key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "stripe_webhook_secret" {
  description = "Stripe webhook signing secret"
  type        = string
  sensitive   = true
  default     = ""
}

# ==============================================================================
# Service Sizing
# ==============================================================================

variable "web_replicas" {
  description = "Number of web server replicas"
  type        = number
  default     = 1
}

variable "sidekiq_replicas" {
  description = "Number of Sidekiq worker replicas"
  type        = number
  default     = 1
}

variable "region" {
  description = "Railway deployment region"
  type        = string
  default     = "us-west1"
}

# ==============================================================================
# Cloudflare Configuration
# ==============================================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API token (Zone:DNS:Edit, Zone:Zone:Read, Zone:Zone Settings:Edit)"
  type        = string
  sensitive   = true
}

variable "cloudflare_domain" {
  description = "Root domain managed in Cloudflare (e.g., example.com)"
  type        = string
}
