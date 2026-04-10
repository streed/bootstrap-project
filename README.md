# bootstrap-rails

A CLI tool that scaffolds production-ready Rails 8 projects with batteries included.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/streed/bootstrap-project/main/install.sh | bash
```

Then generate a project:

```bash
bootstrap-rails my_app
```

That's it. Everything installs to `~/.bootstrap-rails/` with a symlink in `~/.local/bin/` -- no `sudo` needed. If `~/.local/bin` isn't in your PATH, the installer will print what to add to your shell profile.

### Update

```bash
bootstrap-rails --update
```

### Uninstall

```bash
~/.bootstrap-rails/uninstall.sh
```

## What You Get

| Component | Technology |
|---|---|
| Framework | Rails 8+ |
| Database | PostgreSQL 16 |
| Cache/Queue | Redis 7 |
| Background Jobs | Sidekiq 7 |
| Payments | Stripe |
| Authentication | Devise |
| Authorization | Pundit (RBAC) |
| Service Layer | dry-rb (dry-monads, dry-validation, dry-struct, dry-types) |
| Frontend | Stimulus + Turbo (Hotwire), Tailwind CSS |
| Health Checks | `/health`, `/health/db`, `/health/redis` |
| Local Dev | Docker Compose with hot code reload |
| Production | Docker multi-stage build |
| DNS & CDN | Cloudflare (SSL, caching, redirects) |
| Deployment | Terraform for Railway.com + Cloudflare |
| Test Suite | RSpec request, policy, and service specs |

## Prerequisites

- Ruby 3.3+
- Rails 8+
- Node.js 20+
- Docker & Docker Compose (for local development)
- Terraform 1.5+ (for deployment)

## Usage

```bash
bootstrap-rails <project-name> [options]
```

| Flag | Description |
|---|---|
| `--path DIR` | Create the project in a specific directory (default: `.`) |
| `--skip-bundle` | Skip `bundle install` (Docker-only workflows) |
| `--with-system-tests` | Include Capybara + Selenium system tests |
| `--version`, `-v` | Print the installed version |
| `--update` | Update to the latest version from GitHub |
| `--help`, `-h` | Show usage information |

```bash
# Generate in a specific directory
bootstrap-rails my_app --path ~/projects

# Skip bundle (build in Docker instead)
bootstrap-rails my_app --skip-bundle

# Include Capybara browser tests
bootstrap-rails my_app --with-system-tests
```

## Quick Start

### Docker (Recommended)

```bash
bootstrap-rails my_app
cd my_app
cp .env.example .env       # edit with your settings
docker compose up --build
```

Your app is running at `http://localhost:3000` with hot code reload, PostgreSQL, Redis, and Sidekiq.

### Without Docker

```bash
bootstrap-rails my_app
cd my_app
cp .env.example .env       # point to local Postgres/Redis
bundle install
rails db:create db:migrate
bin/dev
```

### Local Development with Docker (Recommended)

```bash
cd my_app_name

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Start everything
docker compose up --build

# In another terminal, create the database
docker compose exec web rails db:create db:migrate
```

Your app is running at `http://localhost:3000` with:
- Hot code reload (source is mounted as a volume)
- PostgreSQL on port 5432
- Redis on port 6379
- Sidekiq processing background jobs

### Local Development Without Docker

```bash
cd my_app_name

cp .env.example .env
# Edit .env - point POSTGRES_HOST and REDIS_URL to local services

bundle install
rails db:create db:migrate

# Start all services
bin/dev
```

## Project Structure

```
my_app_name/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb   # Pundit integration
│   │   ├── health_controller.rb        # Health check endpoints
│   │   └── home_controller.rb          # Landing page
│   ├── policies/
│   │   └── application_policy.rb       # Base Pundit policy
│   └── services/
│       ├── application_service.rb      # dry-rb base service
│       └── example_service.rb          # Example service pattern
├── config/
│   ├── initializers/
│   │   ├── active_job.rb               # Sidekiq adapter
│   │   ├── dry_rb.rb                   # dry-types setup
│   │   ├── pundit.rb                   # Pundit config
│   │   ├── sidekiq.rb                  # Sidekiq Redis config
│   │   └── stripe.rb                   # Stripe API config
│   ├── database.yml                    # PostgreSQL config
│   ├── cable.yml                       # Action Cable via Redis
│   ├── sidekiq.yml                     # Queue configuration
│   └── routes.rb                       # Routes with health checks
├── spec/                               # RSpec test suite
│   ├── requests/                       # Request (integration) specs
│   ├── policies/                       # Pundit policy specs
│   ├── services/                       # Service object specs
│   ├── system/                         # Capybara system specs (optional)
│   ├── factories/                      # FactoryBot factories
│   └── support/                        # Test helpers and config
├── terraform/                          # Railway.com + Cloudflare deployment
│   ├── providers.tf                    # Railway + Cloudflare providers
│   ├── main.tf                         # Railway infrastructure
│   ├── cloudflare.tf                   # DNS, SSL, CDN, caching rules
│   ├── variables.tf
│   └── outputs.tf
├── Dockerfile                          # Production multi-stage build
├── Dockerfile.dev                      # Development with hot reload
├── docker-compose.yml                  # Local dev stack
├── Procfile                            # Production process types
├── Procfile.dev                        # Development process types
└── .env.example                        # Environment template
```

## Service Layer (dry-rb)

Services use `dry-monads` for railway-oriented programming and `dry-validation` for input validation:

```ruby
class Users::CreateService < ApplicationService
  option :name,  type: Types::Strict::String
  option :email, type: Types::Strict::String

  class Contract < Dry::Validation::Contract
    params do
      required(:name).filled(:string)
      required(:email).filled(:string, format?: /@/)
    end
  end

  def call
    validation = Contract.new.call(name:, email:)
    return Failure(validation.errors.to_h) if validation.failure?

    user = User.create!(name:, email:)
    Success(user)
  rescue ActiveRecord::RecordInvalid => e
    Failure(e.record.errors.full_messages)
  end
end

# In a controller:
result = Users::CreateService.call(name: params[:name], email: params[:email])

if result.success?
  redirect_to result.value!
else
  flash[:alert] = result.failure
  render :new
end
```

## Authentication & Authorization

### Devise (Authentication)

Devise is pre-configured with a `User` model including an `admin` boolean field:

```ruby
# Routes are already configured:
# devise_for :users
#
# Available helpers:
# current_user, user_signed_in?, authenticate_user!
```

### Pundit (Authorization)

The `ApplicationController` includes Pundit with automatic policy verification:

```ruby
# Create a policy for any model:
class PostPolicy < ApplicationPolicy
  def update?
    owner_or_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end
end

# In your controller:
def update
  @post = Post.find(params[:id])
  authorize @post
  # ...
end
```

## Health Checks

Three endpoints are available without authentication:

| Endpoint | Description |
|---|---|
| `GET /health` | Application status, version, Ruby/Rails versions |
| `GET /health/db` | PostgreSQL connectivity check |
| `GET /health/redis` | Redis connectivity check |

```json
// GET /health
{
  "status": "ok",
  "timestamp": "2025-01-15T10:30:00Z",
  "version": "0.1.0",
  "rails": "8.0.1",
  "ruby": "3.3.0"
}
```

## Stripe Integration

Stripe is pre-configured via `config/initializers/stripe.rb`. Set your keys in `.env`:

```bash
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

## Deployment to Railway.com + Cloudflare

### Prerequisites

1. A Railway account with an API token
2. A Cloudflare account with your domain's nameservers pointed to Cloudflare
3. Terraform 1.5+
4. Your Docker image pushed to a container registry

### Cloudflare API Token

Create an API token at [Cloudflare Dashboard > Profile > API Tokens](https://dash.cloudflare.com/profile/api-tokens) with these permissions:

| Permission | Access |
|---|---|
| Zone > DNS | Edit |
| Zone > Zone | Read |
| Zone > Zone Settings | Edit |

Scope the token to your specific zone (domain).

### Deploy

```bash
cd terraform

# Create a terraform.tfvars (not committed to git)
cat > terraform.tfvars <<EOF
railway_api_token   = "your-railway-token"
project_name        = "my-rails-app"
docker_image        = "ghcr.io/your-org/my-rails-app:latest"
rails_master_key    = "your-master-key"
secret_key_base     = "your-secret-key-base"
stripe_secret_key   = "sk_live_..."
stripe_publishable_key = "pk_live_..."
stripe_webhook_secret  = "whsec_..."
cloudflare_api_token   = "your-cloudflare-token"
cloudflare_domain      = "example.com"
EOF

terraform init
terraform plan
terraform apply
```

After Terraform creates the infrastructure, configure environment variables in the Railway dashboard for each service (see comments in `terraform/main.tf` for the full list).

### Infrastructure Created

**Railway:**
- **Railway Project** with a default environment
- **Web Service** - Rails app from your Docker image with a generated domain
- **Sidekiq Service** - Background worker from the same Docker image
- **PostgreSQL** - Database with TCP proxy for external access
- **Redis** - Cache and queue store with TCP proxy

**Cloudflare:**
- **DNS Records** - CNAME for apex and `www` pointing to Railway domain
- **SSL/TLS** - Full mode with minimum TLS 1.2, always-use-HTTPS
- **www Redirect** - 301 redirect from `www.example.com` to `example.com`
- **Cache Rules** - Aggressive caching for static assets (30 days), cache bypass for `/health`, auth routes, and `/sidekiq`
- **Performance** - Brotli compression, Early Hints, HTTP/3 enabled
- **Security** - Browser integrity check, medium security level

## Docker Details

### Development (`Dockerfile.dev`)

- Full Ruby development image with all build tools
- Source code mounted as volume for hot reload
- Gems cached in a named volume (`bundle_cache`)
- Node modules cached in a named volume
- Entrypoint handles gem/npm installs and DB preparation

### Production (`Dockerfile`)

- Multi-stage build for minimal image size
- jemalloc for optimized memory allocation
- YJIT enabled for faster Ruby execution
- Non-root user for security
- Bootsnap precompilation for fast boot

## Environment Variables

See `.env.example` for the full list. Key variables:

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `REDIS_URL` | Redis connection string |
| `RAILS_MASTER_KEY` | Credentials decryption key |
| `SECRET_KEY_BASE` | Session/cookie signing key |
| `STRIPE_SECRET_KEY` | Stripe API key |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook verification |
| `SIDEKIQ_CONCURRENCY` | Number of Sidekiq threads |

## Testing

### Included Specs

The generator creates a full test suite out of the box:

```
spec/
├── requests/
│   ├── health_spec.rb              # Health endpoint tests (all 3 endpoints, success + failure)
│   ├── authentication_spec.rb      # Devise sign-up, sign-in, sign-out, invalid credentials
│   ├── home_spec.rb                # Root page (guest vs authenticated)
│   └── sidekiq_web_spec.rb         # Admin-only access to /sidekiq
├── policies/
│   └── application_policy_spec.rb  # Guest, user, owner, admin permission matrix
├── services/
│   └── example_service_spec.rb     # dry-monads Success/Failure, contract validation
├── support/
│   ├── pundit.rb                   # Pundit matchers
│   └── webmock.rb                  # Disable external HTTP
├── factories/
│   └── users.rb                    # User factory with :admin trait
├── rails_helper.rb                 # Devise helpers, FactoryBot, Shoulda config
└── spec_helper.rb                  # SimpleCov, RSpec config
```

### Running Tests

```bash
# Run the full suite
bundle exec rspec

# Run specific test types
bundle exec rspec spec/requests
bundle exec rspec spec/policies
bundle exec rspec spec/services

# With Docker
docker compose exec web bundle exec rspec
```

### System Tests (Optional)

System tests with Capybara are opt-in. To include them:

```bash
bootstrap-rails my_app --with-system-tests
```

This adds:
- `capybara` and `selenium-webdriver` gems
- Capybara config with headless Chrome (`spec/support/capybara.rb`)
- System specs for home page and authentication flows (`spec/system/`)

System tests require Chrome/Chromium to be installed. In Docker, you'll need to add Chrome to the `Dockerfile.dev` or run system tests outside the container.

### Test Libraries

| Gem | Purpose |
|---|---|
| `rspec-rails` | Testing framework |
| `factory_bot_rails` | Test data factories |
| `faker` | Fake data generation |
| `shoulda-matchers` | One-liner model/controller matchers |
| `webmock` | HTTP request stubbing |
| `pundit-matchers` | Policy spec matchers (`permit_action`, `forbid_action`) |
| `stripe-ruby-mock` | Stripe API mocking |
| `simplecov` | Code coverage reporting |
| `capybara` | Browser simulation (with `--with-system-tests`) |
| `selenium-webdriver` | Chrome driver (with `--with-system-tests`) |

## Alternative Install Methods

### From Source (Makefile)

```bash
git clone https://github.com/streed/bootstrap-project.git
cd bootstrap-project
make install
```

### For Contributors

Symlink from your checkout so edits are reflected immediately:

```bash
git clone https://github.com/streed/bootstrap-project.git
cd bootstrap-project
make link    # symlinks into ~/.local/bin
```

### Environment Override

Point to a custom templates directory:

```bash
export BOOTSTRAP_RAILS_TEMPLATES=/path/to/my/templates
bootstrap-rails my_app
```
