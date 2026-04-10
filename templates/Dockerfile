# syntax=docker/dockerfile:1
# ======================================================================
# Production Dockerfile for Rails 8 Application
# Multi-stage build for minimal final image
# ======================================================================

# Stage 1: Base image
FROM ruby:3.3-slim AS base

WORKDIR /rails

# Install base runtime dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libpq5 \
      libjemalloc2 \
      libvips \
      nodejs \
      && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="1" \
    RUBY_YJIT_ENABLE="1" \
    LD_PRELOAD="libjemalloc.so.2"

# Stage 2: Build dependencies and assets
FROM base AS build

# Install build dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      pkg-config \
      node-gyp \
      python-is-python3 \
      && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install JS dependencies
COPY package.json yarn.lock* package-lock.json* ./
RUN if [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
    elif [ -f package-lock.json ]; then npm ci; \
    else npm install; fi

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot
RUN bundle exec bootsnap precompile app/ lib/

# Precompile assets (requires SECRET_KEY_BASE to be set)
RUN SECRET_KEY_BASE=placeholder_for_precompile bundle exec rails assets:precompile

# Stage 3: Final production image
FROM base

# Copy built artifacts
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Create non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp

USER 1000:1000

# Entrypoint prepares the database
ENTRYPOINT ["./bin/docker-entrypoint"]

EXPOSE 3000

# Default command: start the Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
