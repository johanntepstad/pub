require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module PubHealthcare
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.

    # Norwegian timezone and locale configuration
    config.time_zone = "Europe/Oslo"
    config.i18n.default_locale = :nb
    config.i18n.available_locales = [:nb, :en]

    # Load AI3 orchestration framework
    config.autoload_paths += %W(#{config.root}/lib/ai3)
    config.eager_load_paths += %W(#{config.root}/lib/ai3)

    # Performance configurations
    config.cache_store = :solid_cache_store

    # Security configurations
    config.force_ssl = Rails.env.production?
    config.ssl_options = {
      hsts: { expires: 1.year, subdomains: true, preload: true }
    }

    # Session configuration with Norwegian compliance
    config.session_store :cookie_store,
      key: '_pub_healthcare_session',
      secure: Rails.env.production?,
      httponly: true,
      same_site: :strict

    # Norwegian business compliance
    config.active_record.schema_format = :sql
    
    # AI3 and performance settings
    # TODO: Add rack-cors gem if CORS is needed
    # config.middleware.insert_before 0, Rack::Cors do
    #   allow do
    #     origins '*'
    #     resource '*', headers: :any, methods: [:get, :post, :put, :delete, :options]
    #   end
    # end

    # Circuit breaker and rate limiting configuration
    # TODO: Implement these middleware classes
    # config.middleware.use "CircuitBreakerMiddleware"
    # config.middleware.use "RateLimitMiddleware"
  end
end
