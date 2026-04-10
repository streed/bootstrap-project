# Rails 8 Project Generator

A shell-based generator that scaffolds a production-ready Rails 8 project with batteries included.

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
| Deployment | Terraform for Railway.com |

## Prerequisites

- Ruby 3.3+
- Rails 8+
- Node.js 20+
- Docker & Docker Compose
- Terraform 1.5+ (for deployment)

## Quick Start

### Generate a New Project

```bash
./generate.sh my_app_name
```

Or specify a target directory:

```bash
./generate.sh my_app_name --path ~/projects
```

Skip bundle install (useful for Docker-only workflows):

```bash
./generate.sh my_app_name --skip-bundle
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
├── terraform/                          # Railway.com deployment
│   ├── providers.tf
│   ├── main.tf
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

## Deployment to Railway.com

### Prerequisites

1. A Railway account with an API token
2. Terraform 1.5+
3. Your Docker image pushed to a container registry

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
EOF

terraform init
terraform plan
terraform apply
```

After Terraform creates the infrastructure, configure environment variables in the Railway dashboard for each service (see comments in `terraform/main.tf` for the full list).

### Infrastructure Created

- **Railway Project** with a default environment
- **Web Service** - Rails app from your Docker image with a generated domain
- **Sidekiq Service** - Background worker from the same Docker image
- **PostgreSQL** - Database with TCP proxy for external access
- **Redis** - Cache and queue store with TCP proxy

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

The generated project includes RSpec with supporting gems:

```bash
# Run the test suite
bundle exec rspec

# With Docker
docker compose exec web bundle exec rspec
```

Included test libraries:
- `rspec-rails` - Testing framework
- `factory_bot_rails` - Test data factories
- `faker` - Fake data generation
- `shoulda-matchers` - One-liner model tests
- `webmock` - HTTP request stubbing
- `pundit-matchers` - Policy testing helpers
- `stripe-ruby-mock` - Stripe API mocking
- `simplecov` - Code coverage reporting
