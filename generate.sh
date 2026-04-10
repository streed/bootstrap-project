#!/usr/bin/env bash
set -euo pipefail

#======================================================================
# bootstrap-rails - Rails 8 Project Generator
#
# Generates a fully configured Rails 8 project with:
#   - PostgreSQL + Redis
#   - Sidekiq for background jobs
#   - Stripe integration
#   - Devise authentication + Pundit authorization
#   - dry-rb service layer
#   - Stimulus + Turbo (Hotwire)
#   - Health check endpoints
#   - Docker Compose for local dev (hot reload)
#   - Terraform for Railway.com + Cloudflare deployment
#   - RSpec test suite
#======================================================================

BOOTSTRAP_RAILS_VERSION="$(cat "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")/../VERSION" 2>/dev/null || echo "dev")"

# GitHub repository for updates
GITHUB_REPO="streed/bootstrap-project"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/${GITHUB_REPO}"

#----------------------------------------------------------------------
# Resolve template directory
#
# Priority:
#   1. BOOTSTRAP_RAILS_TEMPLATES env var (user override)
#   2. Installed location: ~/.bootstrap-rails/templates
#   3. Relative to this script: ../templates (repo checkout / Makefile install)
#----------------------------------------------------------------------
resolve_templates_dir() {
  if [[ -n "${BOOTSTRAP_RAILS_TEMPLATES:-}" ]] && [[ -d "$BOOTSTRAP_RAILS_TEMPLATES" ]]; then
    echo "$BOOTSTRAP_RAILS_TEMPLATES"
    return
  fi

  local installed_dir="${HOME}/.bootstrap-rails/templates"
  if [[ -d "$installed_dir" ]]; then
    echo "$installed_dir"
    return
  fi

  # Resolve the real path of this script (follow symlinks)
  local script_path
  script_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
  local script_dir
  script_dir="$(cd "$(dirname "$script_path")" && pwd)"

  # Check for templates in parent dir (installed layout: bin/bootstrap-rails + templates/)
  if [[ -d "${script_dir}/../templates" ]]; then
    echo "$(cd "${script_dir}/../templates" && pwd)"
    return
  fi

  # Check for templates next to script (repo layout: generate.sh + templates/)
  if [[ -d "${script_dir}/templates" ]]; then
    echo "${script_dir}/templates"
    return
  fi

  echo ""
}

TEMPLATES_DIR="$(resolve_templates_dir)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#----------------------------------------------------------------------
# Commands: version, update, help
#----------------------------------------------------------------------
show_version() {
  echo "bootstrap-rails ${BOOTSTRAP_RAILS_VERSION}"
  exit 0
}

do_update() {
  log_info "Checking for updates..."

  if ! command -v git &>/dev/null; then
    log_error "git is required for updates."
    exit 1
  fi

  local install_dir="${HOME}/.bootstrap-rails"

  if [[ -d "${install_dir}/.git" ]]; then
    # Installed via git clone - just pull
    log_info "Updating from GitHub (${GITHUB_REPO})..."
    cd "$install_dir"
    local old_version
    old_version="$(cat VERSION 2>/dev/null || echo "unknown")"

    git fetch origin main --quiet
    git reset --hard origin/main --quiet

    local new_version
    new_version="$(cat VERSION 2>/dev/null || echo "unknown")"

    if [[ "$old_version" == "$new_version" ]]; then
      log_ok "Already up to date (v${new_version})."
    else
      log_ok "Updated: v${old_version} -> v${new_version}"
    fi
  elif [[ -d "$install_dir" ]]; then
    # Installed via Makefile or manual copy - re-clone
    log_warn "Current install was not from git. Re-installing from GitHub..."
    local backup_dir="${install_dir}.backup.$(date +%s)"
    mv "$install_dir" "$backup_dir"
    log_info "Backed up existing install to ${backup_dir}"

    git clone --depth 1 "https://github.com/${GITHUB_REPO}.git" "$install_dir" --quiet

    # Re-link the binary
    local bin_dir="${HOME}/.local/bin"
    mkdir -p "$bin_dir"
    ln -sf "${install_dir}/bin/bootstrap-rails" "${bin_dir}/bootstrap-rails"

    local new_version
    new_version="$(cat "${install_dir}/VERSION" 2>/dev/null || echo "unknown")"
    log_ok "Re-installed v${new_version} from GitHub."
    log_info "You can remove the backup: rm -rf ${backup_dir}"
  else
    log_error "bootstrap-rails is not installed at ${install_dir}."
    log_info "Install first: curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash"
    exit 1
  fi

  exit 0
}

usage() {
  cat <<USAGE
${BOLD}bootstrap-rails${NC} v${BOOTSTRAP_RAILS_VERSION} - Rails 8 Project Generator

${BOLD}USAGE${NC}
  bootstrap-rails <project-name> [options]
  bootstrap-rails --update
  bootstrap-rails --version

${BOLD}ARGUMENTS${NC}
  project-name            Name of the new Rails project (snake_case)

${BOLD}OPTIONS${NC}
  --path DIR              Directory to create the project in (default: .)
  --skip-bundle           Skip running bundle install (Docker-only workflows)
  --with-system-tests     Include Capybara system tests (selenium + headless Chrome)
  --version, -v           Show version
  --update                Update to the latest version from GitHub
  --help, -h              Show this help message

${BOLD}EXAMPLES${NC}
  bootstrap-rails my_saas_app
  bootstrap-rails my_saas_app --path ~/projects
  bootstrap-rails my_saas_app --skip-bundle
  bootstrap-rails my_saas_app --with-system-tests
  bootstrap-rails --update

${BOLD}ENVIRONMENT${NC}
  BOOTSTRAP_RAILS_TEMPLATES   Override the templates directory path

USAGE
  exit 0
}

#----------------------------------------------------------------------
# Parse arguments
#----------------------------------------------------------------------
PROJECT_NAME=""
TARGET_DIR="."
SKIP_BUNDLE=false
WITH_SYSTEM_TESTS=false

# Handle zero-args
if [[ $# -eq 0 ]]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --version|-v)        show_version ;;
    --update)            do_update ;;
    --path)              TARGET_DIR="$2"; shift 2 ;;
    --skip-bundle)       SKIP_BUNDLE=true; shift ;;
    --with-system-tests) WITH_SYSTEM_TESTS=true; shift ;;
    --help|-h)           usage ;;
    -*)                  log_error "Unknown option: $1"; echo ""; usage ;;
    *)                   PROJECT_NAME="$1"; shift ;;
  esac
done

if [[ -z "$PROJECT_NAME" ]]; then
  log_error "Project name is required."
  usage
fi

# Validate project name
if [[ ! "$PROJECT_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
  log_error "Project name must be snake_case (lowercase letters, numbers, underscores, starting with a letter)."
  exit 1
fi

# Validate templates directory
if [[ -z "$TEMPLATES_DIR" ]] || [[ ! -d "$TEMPLATES_DIR" ]]; then
  log_error "Templates directory not found."
  log_info "Expected at one of:"
  log_info "  \$BOOTSTRAP_RAILS_TEMPLATES"
  log_info "  ~/.bootstrap-rails/templates"
  log_info "  $(dirname "${BASH_SOURCE[0]}")/templates"
  log_info ""
  log_info "Install bootstrap-rails first:"
  log_info "  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash"
  exit 1
fi

PROJECT_PATH="${TARGET_DIR}/${PROJECT_NAME}"

if [[ -d "$PROJECT_PATH" ]]; then
  log_error "Directory '${PROJECT_PATH}' already exists."
  exit 1
fi

#----------------------------------------------------------------------
# Check prerequisites
#----------------------------------------------------------------------
check_command() {
  if ! command -v "$1" &>/dev/null; then
    log_error "$1 is required but not installed."
    exit 1
  fi
}

log_info "bootstrap-rails v${BOOTSTRAP_RAILS_VERSION}"
log_info "Checking prerequisites..."
check_command ruby
check_command rails
check_command bundler
check_command node
log_ok "All prerequisites found."

RAILS_VERSION=$(rails --version | grep -oP '\d+\.\d+')
RAILS_MAJOR=$(echo "$RAILS_VERSION" | cut -d. -f1)

if [[ "$RAILS_MAJOR" -lt 8 ]]; then
  log_error "Rails 8+ is required. Found: $(rails --version)"
  exit 1
fi

log_ok "Rails version: $(rails --version)"

#----------------------------------------------------------------------
# Step 1: Generate Rails project
#----------------------------------------------------------------------
log_info "Generating Rails 8 project: ${PROJECT_NAME}..."

RAILS_OPTS=(
  --database=postgresql
  --css=tailwind
  --javascript=esbuild
  --skip-jbuilder
  --skip-test
)

if $SKIP_BUNDLE; then
  RAILS_OPTS+=(--skip-bundle)
fi

cd "$TARGET_DIR"
rails new "$PROJECT_NAME" "${RAILS_OPTS[@]}"
cd "$PROJECT_NAME"

PROJECT_PATH="$(pwd)"
log_ok "Rails project generated at ${PROJECT_PATH}"

#----------------------------------------------------------------------
# Step 2: Update Gemfile
#----------------------------------------------------------------------
log_info "Updating Gemfile with project dependencies..."

cat "${TEMPLATES_DIR}/Gemfile.append" >> Gemfile

# Optional: Capybara system tests
if $WITH_SYSTEM_TESTS; then
  log_info "Including Capybara system test gems..."
  cat "${TEMPLATES_DIR}/Gemfile.system_tests" >> Gemfile
fi

if ! $SKIP_BUNDLE; then
  log_info "Running bundle install..."
  bundle install
  log_ok "Bundle install complete."
fi

#----------------------------------------------------------------------
# Step 3: Copy template files
#----------------------------------------------------------------------
log_info "Copying configuration templates..."

# Config initializers
cp "${TEMPLATES_DIR}/config/initializers/sidekiq.rb"  config/initializers/sidekiq.rb
cp "${TEMPLATES_DIR}/config/initializers/stripe.rb"   config/initializers/stripe.rb
cp "${TEMPLATES_DIR}/config/initializers/dry_rb.rb"   config/initializers/dry_rb.rb
cp "${TEMPLATES_DIR}/config/initializers/pundit.rb"   config/initializers/pundit.rb

# Sidekiq config
cp "${TEMPLATES_DIR}/config/sidekiq.yml" config/sidekiq.yml

# Application controller (with Pundit)
cp "${TEMPLATES_DIR}/app/controllers/application_controller.rb" app/controllers/application_controller.rb

# Health controller
cp "${TEMPLATES_DIR}/app/controllers/health_controller.rb" app/controllers/health_controller.rb

# Health views
mkdir -p app/views/health
cp "${TEMPLATES_DIR}/app/views/health/show.json.jbuilder" app/views/health/show.json.jbuilder

# Services layer
mkdir -p app/services
cp "${TEMPLATES_DIR}/app/services/application_service.rb" app/services/application_service.rb
cp "${TEMPLATES_DIR}/app/services/example_service.rb"     app/services/example_service.rb

# Policies
mkdir -p app/policies
cp "${TEMPLATES_DIR}/app/policies/application_policy.rb" app/policies/application_policy.rb

# Docker files
cp "${TEMPLATES_DIR}/Dockerfile"          Dockerfile
cp "${TEMPLATES_DIR}/Dockerfile.dev"      Dockerfile.dev
cp "${TEMPLATES_DIR}/docker-compose.yml"  docker-compose.yml
cp "${TEMPLATES_DIR}/.dockerignore"       .dockerignore

# Entrypoint scripts
mkdir -p bin
cp "${TEMPLATES_DIR}/bin/docker-entrypoint"      bin/docker-entrypoint
cp "${TEMPLATES_DIR}/bin/docker-entrypoint-dev"   bin/docker-entrypoint-dev
chmod +x bin/docker-entrypoint bin/docker-entrypoint-dev

# Procfile
cp "${TEMPLATES_DIR}/Procfile"     Procfile
cp "${TEMPLATES_DIR}/Procfile.dev" Procfile.dev

# Environment
cp "${TEMPLATES_DIR}/.env.example" .env.example
cp "${TEMPLATES_DIR}/.env.example" .env

# Terraform
mkdir -p terraform
cp "${TEMPLATES_DIR}/terraform/main.tf"                    terraform/main.tf
cp "${TEMPLATES_DIR}/terraform/variables.tf"               terraform/variables.tf
cp "${TEMPLATES_DIR}/terraform/outputs.tf"                 terraform/outputs.tf
cp "${TEMPLATES_DIR}/terraform/providers.tf"               terraform/providers.tf
cp "${TEMPLATES_DIR}/terraform/production.tfvars.example"  terraform/production.tfvars.example
cp "${TEMPLATES_DIR}/terraform/cloudflare.tf"              terraform/cloudflare.tf

# RSpec test suite
mkdir -p spec/{requests,policies,services,support,factories}
cp "${TEMPLATES_DIR}/spec/.rspec"                                .rspec
cp "${TEMPLATES_DIR}/spec/spec_helper.rb"                        spec/spec_helper.rb
cp "${TEMPLATES_DIR}/spec/rails_helper.rb"                       spec/rails_helper.rb
cp "${TEMPLATES_DIR}/spec/support/pundit.rb"                     spec/support/pundit.rb
cp "${TEMPLATES_DIR}/spec/support/webmock.rb"                    spec/support/webmock.rb
cp "${TEMPLATES_DIR}/spec/factories/users.rb"                    spec/factories/users.rb
cp "${TEMPLATES_DIR}/spec/requests/health_spec.rb"               spec/requests/health_spec.rb
cp "${TEMPLATES_DIR}/spec/requests/authentication_spec.rb"       spec/requests/authentication_spec.rb
cp "${TEMPLATES_DIR}/spec/requests/home_spec.rb"                 spec/requests/home_spec.rb
cp "${TEMPLATES_DIR}/spec/requests/sidekiq_web_spec.rb"          spec/requests/sidekiq_web_spec.rb
cp "${TEMPLATES_DIR}/spec/policies/application_policy_spec.rb"   spec/policies/application_policy_spec.rb
cp "${TEMPLATES_DIR}/spec/services/example_service_spec.rb"      spec/services/example_service_spec.rb

# Optional: Capybara system tests
if $WITH_SYSTEM_TESTS; then
  log_info "Including Capybara system test files..."
  mkdir -p spec/system
  cp "${TEMPLATES_DIR}/spec/support/capybara.rb"           spec/support/capybara.rb
  cp "${TEMPLATES_DIR}/spec/system/home_spec.rb"           spec/system/home_spec.rb
  cp "${TEMPLATES_DIR}/spec/system/authentication_spec.rb" spec/system/authentication_spec.rb
  log_ok "System tests included."
fi

log_ok "Template files copied."

#----------------------------------------------------------------------
# Step 4: Update Rails configuration files
#----------------------------------------------------------------------
log_info "Configuring Rails application..."

# Update database.yml to use environment variables
cat > config/database.yml <<'DBYML'
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  url: <%= ENV["DATABASE_URL"] %>

development:
  <<: *default
  database: <%= ENV.fetch("POSTGRES_DB") { "app_development" } %>
  host: <%= ENV.fetch("POSTGRES_HOST") { "localhost" } %>
  username: <%= ENV.fetch("POSTGRES_USER") { "postgres" } %>
  password: <%= ENV.fetch("POSTGRES_PASSWORD") { "postgres" } %>

test:
  <<: *default
  database: <%= ENV.fetch("POSTGRES_DB") { "app_test" } %>_test
  host: <%= ENV.fetch("POSTGRES_HOST") { "localhost" } %>
  username: <%= ENV.fetch("POSTGRES_USER") { "postgres" } %>
  password: <%= ENV.fetch("POSTGRES_PASSWORD") { "postgres" } %>

production:
  <<: *default
DBYML

# Update config/application.rb to load services
cat >> config/application.rb <<'APPCONFIG'

# Autoload service layer
# config.autoload_paths += %W[#{config.root}/app/services]
APPCONFIG

# Configure Active Job to use Sidekiq
cat > config/initializers/active_job.rb <<'ACTIVEJOB'
Rails.application.config.active_job.queue_adapter = :sidekiq
ACTIVEJOB

# Update routes
cat > config/routes.rb <<'ROUTES'
require "sidekiq/web"

Rails.application.routes.draw do
  # Sidekiq Web UI (admin only)
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  # Devise authentication routes
  devise_for :users

  # Health check endpoints
  get "health",      to: "health#show",      as: :health
  get "health/db",   to: "health#database",  as: :health_db
  get "health/redis", to: "health#redis",    as: :health_redis

  # Root path
  root "home#index"
end
ROUTES

# Create home controller
mkdir -p app/controllers
cat > app/controllers/home_controller.rb <<'HOMECTRL'
class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
  end
end
HOMECTRL

# Create home view
mkdir -p app/views/home
cat > app/views/home/index.html.erb <<'HOMEVIEW'
<div class="container mx-auto px-4 py-16">
  <h1 class="text-4xl font-bold text-center mb-8">Welcome</h1>
  <p class="text-center text-gray-600">Your Rails 8 application is running.</p>

  <div class="mt-8 flex justify-center gap-4">
    <% if user_signed_in? %>
      <%= link_to "Sign Out", destroy_user_session_path, data: { turbo_method: :delete }, class: "btn btn-secondary" %>
    <% else %>
      <%= link_to "Sign In", new_user_session_path, class: "btn btn-primary" %>
      <%= link_to "Sign Up", new_user_registration_path, class: "btn btn-secondary" %>
    <% end %>
  </div>
</div>
HOMEVIEW

log_ok "Rails configuration updated."

#----------------------------------------------------------------------
# Step 5: Run generators (if bundle was installed)
#----------------------------------------------------------------------
if ! $SKIP_BUNDLE; then
  log_info "Running Devise install..."
  bundle exec rails generate devise:install 2>/dev/null || log_warn "Devise install generator skipped."

  log_info "Generating Devise User model..."
  bundle exec rails generate devise User admin:boolean 2>/dev/null || log_warn "Devise User model generator skipped."

  # Add default admin: false to migration
  MIGRATION_FILE=$(find db/migrate -name "*_devise_create_users.rb" 2>/dev/null | head -1)
  if [[ -n "$MIGRATION_FILE" ]]; then
    sed -i 's/t.boolean :admin/t.boolean :admin, default: false, null: false/' "$MIGRATION_FILE"
    log_ok "User migration updated with admin default."
  fi

  log_info "Running Pundit install..."
  bundle exec rails generate pundit:install 2>/dev/null || log_warn "Pundit install generator skipped."

  log_info "Running RSpec install..."
  bundle exec rails generate rspec:install 2>/dev/null || log_warn "RSpec install generator skipped."

  log_ok "Generators complete."
fi

#----------------------------------------------------------------------
# Step 6: Configure cable.yml for Redis
#----------------------------------------------------------------------
cat > config/cable.yml <<'CABLEYML'
development:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
CABLEYML

#----------------------------------------------------------------------
# Step 7: Update .gitignore
#----------------------------------------------------------------------
cat >> .gitignore <<'GITIGNORE'

# Environment files
.env
.env.local
.env.*.local

# Terraform
terraform/.terraform/
terraform/*.tfstate
terraform/*.tfstate.backup
terraform/*.tfvars
terraform/.terraform.lock.hcl

# Docker
docker-compose.override.yml

# IDE
.idea/
.vscode/
GITIGNORE

#----------------------------------------------------------------------
# Step 8: Initialize git
#----------------------------------------------------------------------
log_info "Initializing git repository..."
git init
git add -A
git commit -m "Initial commit: Rails 8 project with full stack setup

Generated with bootstrap-rails v${BOOTSTRAP_RAILS_VERSION}

- PostgreSQL + Redis
- Sidekiq for background jobs
- Devise authentication + Pundit authorization
- Stripe integration
- dry-rb service layer
- Stimulus + Turbo (Hotwire)
- Health check endpoints
- Docker Compose for local development
- Terraform for Railway.com deployment
- Cloudflare DNS, SSL, and CDN configuration
- RSpec test suite with request, policy, and service specs"

log_ok "Git repository initialized."

#----------------------------------------------------------------------
# Done!
#----------------------------------------------------------------------
echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN} Project '${PROJECT_NAME}' generated successfully!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. cd ${PROJECT_NAME}"
echo ""
echo "  2. Docker (recommended):"
echo "     cp .env.example .env    # Edit with your settings"
echo "     docker compose up --build"
echo ""
echo "  3. Local development:"
echo "     cp .env.example .env    # Edit with your settings"
echo "     bin/rails db:create db:migrate"
echo "     bin/dev"
echo ""
echo "  4. Deploy to Railway:"
echo "     cd terraform"
echo "     terraform init"
echo "     terraform plan"
echo "     terraform apply"
echo ""
echo "  For more details, see the README.md in the project directory."
echo ""
