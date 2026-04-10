# ==============================================================================
# Railway.com Infrastructure
#
# Deploys a Rails 8 application with:
#   - Rails web service (Docker)
#   - Sidekiq background worker (Docker)
#   - PostgreSQL database
#   - Redis cache/queue
#
# Usage:
#   cd terraform
#   terraform init
#   terraform plan -var-file="production.tfvars"
#   terraform apply -var-file="production.tfvars"
# ==============================================================================

# ------------------------------------------------------------------------------
# Project
# ------------------------------------------------------------------------------

resource "railway_project" "app" {
  name = var.project_name
}

# ------------------------------------------------------------------------------
# PostgreSQL Database
# ------------------------------------------------------------------------------

resource "railway_service" "postgres" {
  name         = "postgres"
  project_id   = railway_project.app.id
  source_image = "postgres:16-alpine"
}

resource "railway_tcp_proxy" "postgres" {
  service_id       = railway_service.postgres.id
  environment_id   = railway_project.app.default_environment.id
  application_port = 5432
}

# ------------------------------------------------------------------------------
# Redis
# ------------------------------------------------------------------------------

resource "railway_service" "redis" {
  name         = "redis"
  project_id   = railway_project.app.id
  source_image = "redis:7-alpine"
}

resource "railway_tcp_proxy" "redis" {
  service_id       = railway_service.redis.id
  environment_id   = railway_project.app.default_environment.id
  application_port = 6379
}

# ------------------------------------------------------------------------------
# Rails Web Service
# ------------------------------------------------------------------------------

resource "railway_service" "web" {
  name         = "web"
  project_id   = railway_project.app.id
  source_image = var.docker_image

  # Private registry auth (if needed)
  # source_image_registry_username = var.docker_registry_username
  # source_image_registry_password = var.docker_registry_password
}

resource "railway_service_domain" "web" {
  service_id     = railway_service.web.id
  environment_id = railway_project.app.default_environment.id
}

# ------------------------------------------------------------------------------
# Sidekiq Worker Service
# ------------------------------------------------------------------------------

resource "railway_service" "sidekiq" {
  name         = "sidekiq"
  project_id   = railway_project.app.id
  source_image = var.docker_image

  # Private registry auth (if needed)
  # source_image_registry_username = var.docker_registry_username
  # source_image_registry_password = var.docker_registry_password
}

# ==============================================================================
# IMPORTANT: Environment Variable Configuration
#
# Railway manages environment variables through its dashboard and CLI.
# The community Terraform provider has limited support for setting env vars
# as resources. After running `terraform apply`, configure these environment
# variables via the Railway dashboard or CLI:
#
# For the `web` and `sidekiq` services:
#   RAILS_ENV=production
#   RAILS_MASTER_KEY=<your-master-key>
#   SECRET_KEY_BASE=<your-secret-key-base>
#   RAILS_LOG_TO_STDOUT=1
#   RAILS_SERVE_STATIC_FILES=1
#   DATABASE_URL=${{postgres.DATABASE_URL}}
#   REDIS_URL=${{redis.REDIS_URL}}
#   STRIPE_PUBLISHABLE_KEY=<your-stripe-key>
#   STRIPE_SECRET_KEY=<your-stripe-secret>
#   STRIPE_WEBHOOK_SECRET=<your-webhook-secret>
#   PORT=3000
#
# For the `postgres` service:
#   POSTGRES_USER=postgres
#   POSTGRES_PASSWORD=<generate-strong-password>
#   POSTGRES_DB=app_production
#   PGDATA=/var/lib/postgresql/data/pgdata
#
# For the `redis` service:
#   (no additional vars needed for default config)
#
# For the `sidekiq` service, also set:
#   SIDEKIQ_CONCURRENCY=10
#
# Railway variable references (${{service.VAR}}) allow services to
# reference each other's variables automatically.
# ==============================================================================
