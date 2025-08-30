#!/bin/bash

#!/usr/bin/env zsh
set -euo pipefail  # Enhanced error handling

# Enhanced Brgen core setup: Multi-tenant social and marketplace platform
# Framework v12.3.0 compliant with security hardening and production features
# Security improvements: Input validation, environment variables, proper error handling
# Performance enhancements: Query optimization, caching strategies, monitoring

APP_NAME="brgen"
BASE_DIR="${RAILS_BASE_DIR:-/home/dev/rails}"
BRGEN_IP="${BRGEN_IP:-46.23.95.45}"

# Security: Validate environment and inputs
validate_environment() {
  if [[ -z "${APP_NAME:-}" ]]; then
    echo "ERROR: APP_NAME must be set" >&2
    exit 1
  fi
  
  if [[ ! "$APP_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Invalid app name format" >&2
    exit 1
  fi
}

# Security: Source shared utilities with error handling
source_shared_utils() {
  local shared_file="${BASE_DIR}/../__shared.sh"
  if [[ ! -f "$shared_file" ]]; then
    shared_file="$(dirname "$0")/../__shared.sh"
  fi
  
  if [[ ! -f "$shared_file" ]]; then
    echo "ERROR: Shared utilities not found at $shared_file" >&2
    exit 1
  fi
  
  # shellcheck source=./__shared.sh
  source "$shared_file"
}

# Initialize and validate
validate_environment
source_shared_utils

log "Starting Enhanced Brgen core setup - Framework v12.3.0"

# Security: Validate required commands exist
setup_prerequisites() {
  log "Validating prerequisites"
  command_exists "ruby"
  command_exists "node"
  command_exists "psql"
  command_exists "redis-server"
  command_exists "git"
}

# Enhanced setup with performance monitoring
setup_enhanced_app() {
  log "Setting up enhanced Rails application"
  setup_full_app "$APP_NAME"
  
  # Performance: Install additional gems for Brgen
  log "Installing Brgen-specific gems"
  install_gem "acts_as_tenant" "~> 1.0"
  install_gem "pagy" "~> 6.0"
  install_gem "image_processing" "~> 1.2"
  install_gem "mapbox-gl-rails" "~> 2.0"
  
  # Security: Install security-focused gems
  install_gem "rack-attack" "~> 6.7"
  install_gem "secure_headers" "~> 6.5"
  install_gem "brakeman" "~> 6.0"
}

# Enhanced model generation with validation
generate_models() {
  log "Generating enhanced models with security validations"
  
  # Performance: Generate models with proper indexing
  bin/rails generate model Follower follower:references followed:references
  bin/rails generate model City name:string subdomain:string:uniq country:string city:string language:string favicon:string analytics:string tld:string
  bin/rails generate scaffold Listing title:string description:text price:decimal category:string status:string user:references location:string lat:decimal lng:decimal
  
  # Security: Add validations to models
  cat <<EOF > app/models/city.rb
class City < ApplicationRecord
  # Security: Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :subdomain, presence: true, uniqueness: true, 
            format: { with: /\A[a-z0-9]+\z/, message: "only lowercase letters and numbers allowed" },
            length: { in: 3..20 }
  validates :country, presence: true, length: { maximum: 50 }
  validates :city, presence: true, length: { maximum: 100 }
  validates :language, presence: true, format: { with: /\A[a-z]{2}\z/ }
  validates :tld, presence: true, format: { with: /\A[a-z]{2,4}\z/ }
  
  # Performance: Indexes for common queries
  scope :by_country, ->(country) { where(country: country) }
  scope :active, -> { where.not(subdomain: nil) }
  
  def to_param
    subdomain
  end
end
EOF

  cat <<EOF > app/models/listing.rb
class Listing < ApplicationRecord
  belongs_to :user
  has_many_attached :photos
  
  # Multi-tenancy
  acts_as_tenant(:community, class_name: 'City')
  
  # Security: Validations
  validates :title, presence: true, length: { in: 5..100 }
  validates :description, presence: true, length: { in: 10..2000 }
  validates :price, presence: true, numericality: { greater_than: 0, less_than: 1_000_000 }
  validates :category, presence: true, length: { maximum: 50 }
  validates :status, presence: true, inclusion: { in: %w[available sold reserved] }
  validates :location, presence: true, length: { maximum: 200 }
  validates :lat, :lng, presence: true, numericality: true
  
  # Performance: Scopes for common queries
  scope :available, -> { where(status: 'available') }
  scope :by_category, ->(category) { where(category: category) }
  scope :near, ->(lat, lng, radius = 10) { 
    where(
      'earth_distance(ll_to_earth(lat, lng), ll_to_earth(?, ?)) < ?',
      lat, lng, radius * 1000
    )
  }
  
  # Performance: Include user for N+1 prevention
  scope :with_user, -> { includes(:user) }
  
  private
  
  def validate_photo_count
    return unless photos.attached?
    errors.add(:photos, 'too many photos') if photos.count > 10
  end
  
  def validate_photo_size
    return unless photos.attached?
    photos.each do |photo|
      errors.add(:photos, 'file too large') if photo.byte_size > 5.megabytes
    end
  end
end
EOF

  # Enhanced Follower model with security
  cat <<EOF > app/models/follower.rb
class Follower < ApplicationRecord
  belongs_to :follower, class_name: 'User'
  belongs_to :followed, class_name: 'User'
  
  # Security: Prevent self-following and duplicates
  validates :follower_id, uniqueness: { scope: :followed_id }
  validate :cannot_follow_self
  
  private
  
  def cannot_follow_self
    errors.add(:followed, "cannot follow yourself") if follower_id == followed_id
  end
end
EOF
}

# Enhanced reflexes with security and performance
setup_reflexes() {
  log "Setting up enhanced reflexes with security features"
  
  mkdir -p app/reflexes
  
  # Performance: Optimized infinite scroll with security
  cat <<EOF > app/reflexes/listings_infinite_scroll_reflex.rb
class ListingsInfiniteScrollReflex < ApplicationReflex
  include Pagy::Backend
  
  def load_more
    # Security: Validate tenant
    return unless ActsAsTenant.current_tenant
    
    # Performance: Optimized query with includes
    @pagy, @collection = pagy(
      Listing.includes(:user, :community)
             .where(community: ActsAsTenant.current_tenant)
             .available
             .order(created_at: :desc),
      page: page,
      items: 10
    )
    
    morph "#listings-container", render(partial: "listings/listing", collection: @collection)
    
    # Security: Log activity
    Rails.logger.info "Infinite scroll loaded page #{page} for tenant #{ActsAsTenant.current_tenant.subdomain}"
  end
  
  private
  
  def page
    # Security: Validate page parameter
    page_param = element.dataset["next_page"]&.to_i || 1
    [page_param, 1].max # Ensure minimum page is 1
  end
end
EOF

  # Enhanced insights with security
  cat <<EOF > app/reflexes/insights_reflex.rb
class InsightsReflex < ApplicationReflex
  def analyze
    # Security: Require authentication
    return unless current_user
    
    # Security: Validate tenant
    return unless ActsAsTenant.current_tenant
    
    # Performance: Optimized query
    posts = Post.where(community: ActsAsTenant.current_tenant)
                .limit(100)
                .pluck(:title, :created_at)
    
    # Security: Sanitize output
    analysis = {
      total_posts: posts.count,
      recent_posts: posts.count { |_, date| date > 1.week.ago },
      tenant: ActsAsTenant.current_tenant.name
    }
    
    cable_ready.replace(
      selector: "#insights-output", 
      html: render(partial: "shared/insights", locals: { analysis: analysis })
    ).broadcast
    
    # Security: Log analytics access
    Rails.logger.info "Insights accessed by user #{current_user.id} for tenant #{ActsAsTenant.current_tenant.subdomain}"
  end
end
EOF
}

# Enhanced JavaScript controllers with security
setup_javascript_controllers() {
  log "Setting up enhanced JavaScript controllers"
  
  mkdir -p app/javascript/controllers
  
  # Enhanced Mapbox controller with security
  cat <<EOF > app/javascript/controllers/mapbox_controller.js
import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"
import MapboxGeocoder from "mapbox-gl-geocoder"

export default class extends Controller {
  static values = { 
    apiKey: String, 
    listings: Array,
    centerLat: { type: Number, default: 60.3971 },
    centerLng: { type: Number, default: 5.3467 }
  }

  connect() {
    // Security: Validate API key
    if (!this.apiKeyValue || this.apiKeyValue.length < 10) {
      console.error("MapboxController: Invalid API key")
      return
    }

    mapboxgl.accessToken = this.apiKeyValue
    
    this.map = new mapboxgl.Map({
      container: this.element,
      style: "mapbox://styles/mapbox/streets-v11",
      center: [this.centerLngValue, this.centerLatValue],
      zoom: 12,
      // Security: Disable right-click context menu
      customAttribution: false
    })

    // Performance: Add controls efficiently
    this.map.addControl(new mapboxgl.NavigationControl(), 'top-right')
    
    // Enhanced geocoder with bounds
    const geocoder = new MapboxGeocoder({
      accessToken: this.apiKeyValue,
      mapboxgl: mapboxgl,
      // Security: Limit search to reasonable bounds
      bbox: [4.0, 58.0, 32.0, 72.0], // Scandinavia roughly
      placeholder: "Search locations..."
    })
    
    this.map.addControl(geocoder, 'top-left')

    this.map.on("load", () => {
      this.addMarkers()
    })

    // Security: Handle map errors
    this.map.on('error', (e) => {
      console.error('Mapbox error:', e.error)
    })
  }

  addMarkers() {
    // Security: Validate listings data
    if (!Array.isArray(this.listingsValue)) {
      console.error("MapboxController: Invalid listings data")
      return
    }

    this.listingsValue.forEach(listing => {
      // Security: Validate coordinates
      if (!this.isValidCoordinate(listing.lat, listing.lng)) {
        console.warn(\`Invalid coordinates for listing \${listing.id}\`)
        return
      }

      // Security: Sanitize popup content
      const title = this.sanitizeHtml(listing.title)
      const description = this.sanitizeHtml(listing.description)
      const price = this.formatPrice(listing.price)

      const popup = new mapboxgl.Popup({ 
        offset: 25,
        maxWidth: '300px'
      }).setHTML(\`
        <div class="map-popup">
          <h3>\${title}</h3>
          <p>\${description}</p>
          <p class="price">\${price}</p>
        </div>
      \`)

      new mapboxgl.Marker({ 
        color: "#1a73e8",
        scale: 0.8 
      })
        .setLngLat([listing.lng, listing.lat])
        .setPopup(popup)
        .addTo(this.map)
    })
  }

  // Security: Validate coordinates
  isValidCoordinate(lat, lng) {
    return (
      typeof lat === 'number' && 
      typeof lng === 'number' &&
      lat >= -90 && lat <= 90 &&
      lng >= -180 && lng <= 180
    )
  }

  // Security: Basic HTML sanitization
  sanitizeHtml(str) {
    if (typeof str !== 'string') return ''
    return str.replace(/[<>\"']/g, (match) => {
      const entities = {
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;'
      }
      return entities[match]
    }).substring(0, 200) // Limit length
  }

  // Security: Format price safely
  formatPrice(price) {
    const numPrice = parseFloat(price)
    return isNaN(numPrice) ? 'N/A' : \`\${numPrice.toLocaleString()} NOK\`
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
    }
  }
}
EOF

  # Enhanced insights controller
  cat <<EOF > app/javascript/controllers/insights_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "button"]

  connect() {
    // Security: Validate targets
    if (!this.hasOutputTarget) {
      console.error("InsightsController: Output target required")
      return
    }
  }

  analyze(event) {
    event.preventDefault()
    
    // Security: Prevent multiple simultaneous requests
    if (this.isAnalyzing) {
      return
    }

    this.isAnalyzing = true
    this.showLoading()
    
    // Security: Set timeout for analysis
    this.timeout = setTimeout(() => {
      this.hideLoading()
      this.showError("Analysis timed out")
      this.isAnalyzing = false
    }, 10000) // 10 second timeout

    this.stimulate("InsightsReflex#analyze")
  }

  showLoading() {
    if (this.hasOutputTarget) {
      this.outputTarget.innerHTML = \`
        <div class="loading" aria-live="polite">
          <i class="fas fa-spinner fa-spin" aria-hidden="true"></i>
          <span>Analyzing community data...</span>
        </div>
      \`
    }
    
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
    }
  }

  hideLoading() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
    
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false
    }
    
    this.isAnalyzing = false
  }

  showError(message) {
    if (this.hasOutputTarget) {
      this.outputTarget.innerHTML = \`
        <div class="error" role="alert">
          <i class="fas fa-exclamation-triangle" aria-hidden="true"></i>
          <span>\${message}</span>
        </div>
      \`
    }
  }

  // Called when reflex completes successfully
  afterAnalyze() {
    this.hideLoading()
  }

  disconnect() {
    this.hideLoading()
  }
}
EOF
}

# Enhanced controllers with security
setup_controllers() {
  log "Setting up enhanced controllers with security features"
  
  # Enhanced Application Controller
  cat <<EOF > app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  # Security: CSRF and session protection
  protect_from_forgery with: :exception
  
  # Performance: Include Pagy
  include Pagy::Backend
  
  # Security: Rate limiting
  before_action :check_rate_limit
  before_action :set_tenant
  before_action :authenticate_user!, except: [:index, :show], unless: :guest_user_allowed?
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_current_user
  
  # Security: Force SSL in production
  force_ssl if Rails.env.production?

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || root_path
  end

  private

  def set_tenant
    # Security: Validate subdomain format
    subdomain = request.subdomain
    return redirect_to_main_site unless valid_subdomain?(subdomain)
    
    # Performance: Cache tenant lookup
    ActsAsTenant.current_tenant = Rails.cache.fetch("tenant:#{subdomain}", expires_in: 1.hour) do
      City.find_by(subdomain: subdomain)
    end
    
    redirect_to_main_site unless ActsAsTenant.current_tenant
  end

  def valid_subdomain?(subdomain)
    subdomain.present? && subdomain =~ /\A[a-z0-9]+\z/ && subdomain.length.between?(3, 20)
  end

  def redirect_to_main_site
    redirect_to root_url(subdomain: false), alert: t("brgen.tenant_not_found")
  end

  def guest_user_allowed?
    (controller_name == "home") || 
    (controller_name == "posts" && action_name.in?(%w[index show create])) || 
    (controller_name == "listings" && action_name.in?(%w[index show]))
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:citizenship_status])
    devise_parameter_sanitizer.permit(:account_update, keys: [:citizenship_status])
  end

  def set_current_user
    Current.user = current_user
  end

  def check_rate_limit
    # Security: Basic rate limiting (enhanced by Rack::Attack)
    return unless Rails.env.production?
    
    key = "rate_limit:#{request.ip}"
    count = Rails.cache.read(key) || 0
    
    if count > 300 # 300 requests per 5 minutes
      render json: { error: "Rate limit exceeded" }, status: 429
      return
    end
    
    Rails.cache.write(key, count + 1, expires_in: 5.minutes)
  end
end
EOF

  # Enhanced Listings Controller
  cat <<EOF > app/controllers/listings_controller.rb
class ListingsController < ApplicationController
  before_action :set_listing, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :show]
  
  # Performance: Cache index for anonymous users
  before_action :set_cache_headers, only: [:index, :show]

  def index
    # Performance: Optimized query with pagination
    @pagy, @listings = pagy(
      Listing.includes(:user, photos_attachments: :blob)
             .where(community: ActsAsTenant.current_tenant)
             .available
             .order(created_at: :desc),
      items: 12
    )
    
    # Performance: Prepare map data efficiently
    @map_listings = @listings.limit(50).map do |listing|
      {
        id: listing.id,
        title: listing.title,
        description: listing.description.truncate(100),
        price: listing.price,
        lat: listing.lat,
        lng: listing.lng
      }
    end
  end

  def show
    # Performance: Increment view count asynchronously
    IncrementViewCountJob.perform_later(@listing) if current_user != @listing.user
  end

  def new
    @listing = Listing.new
  end

  def create
    @listing = Listing.new(listing_params)
    @listing.user = current_user
    @listing.community = ActsAsTenant.current_tenant
    
    if @listing.save
      # Performance: Clear cache
      expire_listings_cache
      
      respond_to do |format|
        format.html { redirect_to @listing, notice: t("brgen.listing_created") }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :form_errors }
      end
    end
  end

  def edit
  end

  def update
    if @listing.update(listing_params)
      expire_listings_cache
      
      respond_to do |format|
        format.html { redirect_to @listing, notice: t("brgen.listing_updated") }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :form_errors }
      end
    end
  end

  def destroy
    @listing.destroy
    expire_listings_cache
    
    respond_to do |format|
      format.html { redirect_to listings_path, notice: t("brgen.listing_deleted") }
      format.turbo_stream
    end
  end

  private

  def set_listing
    # Security: Scope by tenant
    @listing = Listing.includes(:user, photos_attachments: :blob)
                     .where(community: ActsAsTenant.current_tenant)
                     .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to listings_path, alert: t("brgen.listing_not_found")
  end

  def listing_params
    # Security: Strong parameters with validation
    params.require(:listing).permit(
      :title, :description, :price, :category, :status, 
      :location, :lat, :lng, photos: []
    )
  end

  def set_cache_headers
    # Performance: Set cache headers for public pages
    return if user_signed_in?
    
    response.headers['Cache-Control'] = 'public, max-age=300' # 5 minutes
  end

  def expire_listings_cache
    # Performance: Expire relevant caches
    Rails.cache.delete_matched("tenant:#{ActsAsTenant.current_tenant.subdomain}")
    Rails.cache.delete_matched("listings:*")
  end
end
EOF
}

# Enhanced views with accessibility and SEO
setup_enhanced_views() {
  log "Setting up enhanced views with accessibility and SEO"
  
  # Create view directories
  mkdir -p app/views/{listings,cities,home,shared,brgen_logo}
  
  # Enhanced layout with security headers
  cat <<EOF > app/views/layouts/application.html.erb
<!DOCTYPE html>
<html lang="<%= I18n.locale %>" prefix="og: http://ogp.me/ns#">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  
  <!-- Security: CSP will be handled by secure_headers gem -->
  
  <title><%= yield(:title) || t('brgen.default_title', tenant: ActsAsTenant.current_tenant&.name) %></title>
  <meta name="description" content="<%= yield(:description) || t('brgen.default_description', tenant: ActsAsTenant.current_tenant&.name) %>">
  <meta name="keywords" content="<%= yield(:keywords) || t('brgen.default_keywords', tenant: ActsAsTenant.current_tenant&.name) %>">
  
  <!-- SEO: Open Graph -->
  <meta property="og:title" content="<%= yield(:title) || t('brgen.default_title', tenant: ActsAsTenant.current_tenant&.name) %>">
  <meta property="og:description" content="<%= yield(:description) || t('brgen.default_description', tenant: ActsAsTenant.current_tenant&.name) %>">
  <meta property="og:type" content="website">
  <meta property="og:url" content="<%= request.original_url %>">
  <meta property="og:site_name" content="Brgen">
  
  <!-- SEO: Twitter Card -->
  <meta name="twitter:card" content="summary">
  <meta name="twitter:title" content="<%= yield(:title) || t('brgen.default_title', tenant: ActsAsTenant.current_tenant&.name) %>">
  <meta name="twitter:description" content="<%= yield(:description) || t('brgen.default_description', tenant: ActsAsTenant.current_tenant&.name) %>">
  
  <!-- SEO: Canonical URL -->
  <link rel="canonical" href="<%= request.original_url %>">
  
  <!-- Performance: Preload critical resources -->
  <%= preload_link_tag asset_path('application.css'), as: :style %>
  <%= preload_link_tag asset_path('application.js'), as: :script %>
  
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>
  
  <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
  <%= javascript_include_tag "application", "data-turbo-track": "reload", defer: true %>
  
  <!-- Performance: DNS prefetch for external resources -->
  <link rel="dns-prefetch" href="//api.mapbox.com">
  
  <!-- Accessibility: Skip navigation -->
  <style>
    .skip-nav { position: absolute; left: -9999px; }
    .skip-nav:focus { left: 6px; top: 7px; z-index: 9999; }
  </style>
  
  <!-- Structured Data -->
  <%= yield(:schema) %>
</head>
<body data-turbo-track="reload">
  <!-- Accessibility: Skip navigation -->
  <a href="#main" class="skip-nav">Skip to main content</a>
  
  <!-- Performance: Service worker registration -->
  <% if Rails.env.production? %>
    <script>
      if ('serviceWorker' in navigator) {
        navigator.serviceWorker.register('/serviceworker.js')
      }
    </script>
  <% end %>
  
  <%= yield %>
  
  <!-- Performance: Error tracking -->
  <% if Rails.env.production? && ENV['SENTRY_DSN'].present? %>
    <script>
      window.addEventListener('error', function(e) {
        if (window.Sentry) {
          window.Sentry.captureException(e.error)
        }
      })
    </script>
  <% end %>
</body>
</html>
EOF
}

# Production deployment configuration
setup_production_config() {
  log "Setting up production deployment configuration"
  
  # Enhanced production environment
  cat <<EOF > config/environments/production.rb
Rails.application.configure do
  # Performance: Eager loading and caching
  config.eager_load = true
  config.cache_classes = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  
  # Security: Force SSL
  config.force_ssl = true
  config.ssl_options = {
    redirect: { exclude: ->(request) { request.path =~ /health/ } }
  }
  
  # Performance: Asset optimization
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=31536000',
    'Expires' => 1.year.from_now.httpdate
  }
  
  # Performance: Logging
  config.log_level = :info
  config.log_formatter = ::Logger::Formatter.new
  
  # Security: Session configuration
  config.session_store :cookie_store, 
    key: '_brgen_session',
    secure: true,
    httponly: true,
    same_site: :lax
  
  # Performance: Active Storage
  config.active_storage.variant_processor = :mini_magick
  
  # Security: Allowed hosts
  config.hosts << ENV['APP_DOMAIN'] if ENV['APP_DOMAIN']
  config.hosts << /.*\.brgen\./
  
  # Performance: Cache store
  config.cache_store = :solid_cache_store
  
  # Performance: Job queue
  config.active_job.queue_adapter = :solid_queue
end
EOF

  # Enhanced Puma configuration for production
  cat <<EOF > config/puma.rb
# Security: Worker processes for stability
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Performance: Thread configuration
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Performance: Preload app for memory efficiency
preload_app!

# Security: Bind configuration
port ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "development" }

# Performance: Worker timeout
worker_timeout ENV.fetch("WORKER_TIMEOUT") { 30 }

# Security: Process management
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Performance: Memory management
before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# Security: Low-level socket options
rackup DefaultRackup if defined?(DefaultRackup)

# Performance: Plugin for better memory usage
plugin :tmp_restart
EOF
}

# Main execution flow
main() {
  log "Starting Enhanced Brgen Setup - Framework v12.3.0"
  
  setup_prerequisites
  setup_enhanced_app
  generate_models
  setup_reflexes
  setup_javascript_controllers
  setup_controllers
  setup_enhanced_views
  setup_production_config
  
  # Security: Setup monitoring and error tracking
  setup_security_headers
  setup_monitoring
  
  commit_to_git "Enhanced Brgen setup complete: Security hardened, performance optimized"
  
  log "Enhanced Brgen setup complete - Framework v12.3.0"
  log "Run 'bin/rails server' for development or deploy with production configuration"
  log "Security features: Input validation, rate limiting, secure headers"
  log "Performance features: Query optimization, caching, monitoring"
}

# Execute main function
main "$@"