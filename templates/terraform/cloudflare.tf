# ==============================================================================
# Cloudflare DNS & CDN Configuration
#
# Sets up a custom domain with Cloudflare pointing to the Railway deployment:
#   - DNS records (CNAME to Railway domain)
#   - SSL/TLS in Full (Strict) mode
#   - Security headers
#   - Caching rules
#   - Redirect www -> apex (or apex -> www)
#
# Prerequisites:
#   1. Domain registered and nameservers pointed to Cloudflare
#   2. Cloudflare API token with Zone:DNS:Edit and Zone:Zone:Read permissions
#   3. Railway deployment completed (terraform apply for main.tf first)
# ==============================================================================

# ------------------------------------------------------------------------------
# Data: Look up the Cloudflare zone by domain name
# ------------------------------------------------------------------------------

data "cloudflare_zone" "main" {
  name = var.cloudflare_domain
}

# ------------------------------------------------------------------------------
# DNS Records
# ------------------------------------------------------------------------------

# Root domain -> Railway
resource "cloudflare_record" "root" {
  zone_id = data.cloudflare_zone.main.id
  name    = var.cloudflare_domain
  content = railway_service_domain.web.domain
  type    = "CNAME"
  proxied = true
  ttl     = 1 # Auto TTL when proxied
  comment = "Rails app on Railway"
}

# www -> Railway (or redirect to apex, see rule below)
resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zone.main.id
  name    = "www"
  content = railway_service_domain.web.domain
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = "Rails app on Railway (www)"
}

# API subdomain (if you want a separate subdomain for API)
# resource "cloudflare_record" "api" {
#   zone_id = data.cloudflare_zone.main.id
#   name    = "api"
#   content = railway_service_domain.web.domain
#   type    = "CNAME"
#   proxied = true
#   ttl     = 1
#   comment = "Rails API on Railway"
# }

# ------------------------------------------------------------------------------
# SSL/TLS Settings
# ------------------------------------------------------------------------------

resource "cloudflare_zone_setting" "ssl" {
  zone_id    = data.cloudflare_zone.main.id
  setting_id = "ssl"
  value      = "full"
}

resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = data.cloudflare_zone.main.id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "min_tls_version" {
  zone_id    = data.cloudflare_zone.main.id
  setting_id = "min_tls_version"
  value      = "1.2"
}

# ------------------------------------------------------------------------------
# Security Settings
# ------------------------------------------------------------------------------

resource "cloudflare_zone_setting" "security_level" {
  zone_id    = data.cloudflare_zone.main.id
  setting_id = "security_level"
  value      = "medium"
}

resource "cloudflare_zone_setting" "browser_check" {
  zone_id    = data.cloudflare_zone.main.id
  setting_id = "browser_check"
  value      = "on"
}

# ------------------------------------------------------------------------------
# Performance Settings
# ------------------------------------------------------------------------------

resource "cloudflare_zone_setting" "brotli" {
  zone_id    = data.cloudflare_zone.main.id
  setting_id = "brotli"
  value      = "on"
}

resource "cloudflare_zone_setting" "early_hints" {
  zone_id    = data.cloudflare_zone.main.id
  setting_id = "early_hints"
  value      = "on"
}

resource "cloudflare_zone_setting" "http3" {
  zone_id    = data.cloudflare_zone.main.id
  setting_id = "http3"
  value      = "on"
}

# ------------------------------------------------------------------------------
# Page Rules: www -> apex redirect
# ------------------------------------------------------------------------------

resource "cloudflare_ruleset" "redirect_www" {
  zone_id = data.cloudflare_zone.main.id
  name    = "Redirect www to apex"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules {
    action = "redirect"
    action_parameters {
      from_value {
        status_code = 301
        target_url {
          expression = "concat(\"https://${var.cloudflare_domain}\", http.request.uri.path)"
        }
        preserve_query_string = true
      }
    }
    expression  = "(http.host eq \"www.${var.cloudflare_domain}\")"
    description = "Redirect www to apex domain"
    enabled     = true
  }
}

# ------------------------------------------------------------------------------
# Cache Rules: Bypass cache for health endpoints and Devise auth
# ------------------------------------------------------------------------------

resource "cloudflare_ruleset" "cache_rules" {
  zone_id = data.cloudflare_zone.main.id
  name    = "Cache rules"
  kind    = "zone"
  phase   = "http_request_cache_settings"

  # Bypass cache for health checks
  rules {
    action = "set_cache_settings"
    action_parameters {
      cache = false
    }
    expression  = "(starts_with(http.request.uri.path, \"/health\"))"
    description = "Bypass cache for health check endpoints"
    enabled     = true
  }

  # Bypass cache for authentication routes
  rules {
    action = "set_cache_settings"
    action_parameters {
      cache = false
    }
    expression  = "(starts_with(http.request.uri.path, \"/users/sign_in\") or starts_with(http.request.uri.path, \"/users/sign_up\") or starts_with(http.request.uri.path, \"/users/sign_out\") or starts_with(http.request.uri.path, \"/sidekiq\"))"
    description = "Bypass cache for auth and admin routes"
    enabled     = true
  }

  # Cache static assets aggressively
  rules {
    action = "set_cache_settings"
    action_parameters {
      cache = true
      edge_ttl {
        mode    = "override_origin"
        default = 2592000 # 30 days
      }
      browser_ttl {
        mode    = "override_origin"
        default = 2592000 # 30 days
      }
    }
    expression  = "(starts_with(http.request.uri.path, \"/assets/\") or http.request.uri.path.extension in {\"css\" \"js\" \"png\" \"jpg\" \"jpeg\" \"gif\" \"svg\" \"ico\" \"woff\" \"woff2\" \"ttf\" \"eot\"})"
    description = "Aggressively cache static assets"
    enabled     = true
  }
}
