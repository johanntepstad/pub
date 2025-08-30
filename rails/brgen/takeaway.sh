#!/bin/bash

#!/usr/bin/env zsh
set -euo pipefail  # Enhanced error handling

# Enhanced Takeaway platform setup: Food delivery with real-time tracking
# Framework v12.3.0 compliant with security hardening and performance optimizations
# Security improvements: Payment security, order validation, driver verification
# Performance enhancements: Real-time tracking, route optimization, caching

APP_NAME="brgen_takeaway"
BASE_DIR="${RAILS_BASE_DIR:-/home/dev/rails}"
BRGEN_IP="${BRGEN_IP:-46.23.95.45}"

# Security: Validate environment
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

# Initialize
validate_environment
source_shared_utils

log "Starting Enhanced Takeaway Platform Setup - Framework v12.3.0"

# Enhanced setup with payment and tracking integration
setup_enhanced_takeaway_app() {
  log "Setting up enhanced takeaway application with payment and tracking"
  setup_full_app "$APP_NAME"
  
  # Performance: Install food delivery specific gems
  log "Installing takeaway-specific gems with security focus"
  install_gem "stripe" "~> 8.0"
  install_gem "geocoder" "~> 1.8"
  install_gem "geokit-rails" "~> 2.5"
  install_gem "image_processing" "~> 1.2"
  install_gem "redis-rails" "~> 5.0"
  install_gem "sidekiq" "~> 7.1"
  
  # Security: Payment and validation gems
  install_gem "money-rails" "~> 1.15"
  install_gem "credit_card_validations" "~> 6.0"
  install_gem "phonelib" "~> 0.8"
}

# Enhanced models with security and real-time tracking
generate_enhanced_models() {
  log "Generating enhanced models with security and tracking features"
  
  # Performance: Generate models with proper indexes
  bin/rails generate model Restaurant name:string description:text user:references address:string lat:decimal lng:decimal phone:string cuisine_type:string delivery_fee:decimal min_order:decimal rating:decimal verified:boolean
  bin/rails generate model MenuItem restaurant:references name:string description:text price:decimal category:string available:boolean image_url:string allergies:text prep_time:integer
  bin/rails generate model Order user:references restaurant:references status:string total:decimal delivery_address:string delivery_lat:decimal delivery_lng:decimal estimated_delivery:datetime
  bin/rails generate model OrderItem order:references menu_item:references quantity:integer price:decimal special_instructions:text
  bin/rails generate model DeliveryDriver user:references vehicle_type:string license_number:string available:boolean current_lat:decimal current_lng:decimal verified:boolean
  bin/rails generate model Delivery order:references driver:references status:string pickup_time:datetime delivery_time:datetime tracking_url:string
  bin/rails generate model Payment order:references amount:decimal status:string stripe_payment_intent_id:string payment_method:string
  
  # Security: Enhanced Restaurant model with validation
  cat <<EOF > app/models/restaurant.rb
class Restaurant < ApplicationRecord
  belongs_to :user
  has_many :menu_items, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many_attached :photos
  has_many_attached :documents # For business licenses, etc.
  
  # Geospatial capabilities
  include Geokit::Geocoders
  acts_as_mappable default_units: :kms, lat_column_name: :lat, lng_column_name: :lng
  
  # Security: Comprehensive validations
  validates :name, presence: true, length: { in: 2..100 }
  validates :description, presence: true, length: { in: 10..1000 }
  validates :address, presence: true, length: { maximum: 200 }
  validates :lat, :lng, presence: true, numericality: true
  validates :phone, presence: true, phone: true
  validates :cuisine_type, presence: true, inclusion: { 
    in: %w[italian chinese indian mexican thai japanese american indian mediterranean fast_food pizza burger sushi] 
  }
  validates :delivery_fee, presence: true, numericality: { greater_than_or_equal_to: 0, less_than: 50 }
  validates :min_order, presence: true, numericality: { greater_than: 0, less_than: 1000 }
  validates :rating, numericality: { in: 0.0..5.0 }, allow_nil: true
  
  # Security: Photo validation
  validates :photos, content_type: ['image/png', 'image/jpg', 'image/jpeg'],
            size: { less_than: 10.megabytes }
  validate :photos_limit
  
  # Performance: Scopes for common queries
  scope :verified, -> { where(verified: true) }
  scope :by_cuisine, ->(cuisine) { where(cuisine_type: cuisine) }
  scope :with_low_delivery_fee, -> { where('delivery_fee < ?', 5.0) }
  scope :highly_rated, -> { where('rating >= ?', 4.0) }
  scope :accepting_orders, -> { where(accepting_orders: true) }
  scope :open_now, -> { where(open_now: true) }
  
  # Performance: Geospatial search
  scope :within_delivery_radius, ->(lat, lng, radius = 10) {
    within(radius, origin: [lat, lng])
  }
  
  # Security: Restaurant verification
  def verify!
    update!(verified: true)
    RestaurantVerificationMailer.verified(self).deliver_later
  end
  
  # Performance: Cached average rating
  def update_rating!
    avg_rating = orders.joins(:review).average(:rating)
    update_column(:rating, avg_rating)
  end
  
  # Business logic
  def open_now?
    # Simplified - in production, would check actual business hours
    Time.current.hour.between?(8, 22)
  end
  
  def accepting_orders?
    verified? && open_now? && menu_items.available.any?
  end
  
  private
  
  def photos_limit
    errors.add(:photos, 'maximum 10 photos allowed') if photos.count > 10
  end
end
EOF

  # Enhanced Order model with security and tracking
  cat <<EOF > app/models/order.rb
class Order < ApplicationRecord
  belongs_to :user
  belongs_to :restaurant
  has_many :order_items, dependent: :destroy
  has_one :delivery, dependent: :destroy
  has_one :payment, dependent: :destroy
  has_one :review, dependent: :destroy
  
  # Security: Comprehensive validations
  validates :status, presence: true, inclusion: { 
    in: %w[pending confirmed preparing ready out_for_delivery delivered cancelled] 
  }
  validates :total, presence: true, numericality: { greater_than: 0, less_than: 10000 }
  validates :delivery_address, presence: true, length: { maximum: 500 }
  validates :delivery_lat, :delivery_lng, presence: true, numericality: true
  validates :estimated_delivery, presence: true
  
  # Performance: Status enum for better queries
  enum status: {
    pending: 0,
    confirmed: 1,
    preparing: 2,
    ready: 3,
    out_for_delivery: 4,
    delivered: 5,
    cancelled: 6
  }
  
  # Performance: Scopes
  scope :recent, -> { where('created_at > ?', 1.week.ago) }
  scope :for_restaurant, ->(restaurant) { where(restaurant: restaurant) }
  scope :for_customer, ->(user) { where(user: user) }
  scope :active, -> { where.not(status: [:delivered, :cancelled]) }
  scope :completed, -> { where(status: [:delivered, :cancelled]) }
  
  # Security: State machine for status transitions
  after_update :notify_status_change, if: :saved_change_to_status?
  before_save :calculate_estimated_delivery, if: :will_save_change_to_status?
  
  # Performance: Calculate total from order items
  def calculate_total!
    item_total = order_items.sum { |item| item.quantity * item.price }
    delivery_fee = restaurant.delivery_fee
    tax = (item_total * 0.08).round(2) # 8% tax
    
    self.total = item_total + delivery_fee + tax
    save!
  end
  
  # Real-time tracking
  def tracking_info
    return {} unless delivery
    
    {
      status: status,
      estimated_delivery: estimated_delivery,
      driver_location: delivery.driver&.current_location,
      driver_name: delivery.driver&.user&.name,
      driver_phone: delivery.driver&.user&.phone
    }
  end
  
  # Security: Generate secure tracking token
  def generate_tracking_token!
    self.tracking_token = SecureRandom.hex(16)
    save!
  end
  
  private
  
  def calculate_estimated_delivery
    case status
    when 'confirmed'
      self.estimated_delivery = Time.current + restaurant.avg_prep_time.minutes + 30.minutes
    when 'preparing'
      self.estimated_delivery = Time.current + 20.minutes + delivery_time_estimate
    when 'out_for_delivery'
      self.estimated_delivery = Time.current + delivery_time_estimate
    end
  end
  
  def delivery_time_estimate
    # Simplified distance-based calculation
    distance = Geokit::default_formula.distance_between(
      [restaurant.lat, restaurant.lng],
      [delivery_lat, delivery_lng]
    )
    
    # Assume 30 km/h average delivery speed
    (distance / 30.0 * 60).minutes
  end
  
  def notify_status_change
    # Send real-time updates via ActionCable
    ActionCable.server.broadcast(
      "order_#{id}",
      {
        status: status,
        estimated_delivery: estimated_delivery,
        tracking_info: tracking_info
      }
    )
    
    # Send push notifications
    OrderStatusNotificationJob.perform_later(self)
  end
end
EOF

  # Enhanced Delivery Driver model
  cat <<EOF > app/models/delivery_driver.rb
class DeliveryDriver < ApplicationRecord
  belongs_to :user
  has_many :deliveries, foreign_key: :driver_id, dependent: :destroy
  
  # Security: Validations
  validates :vehicle_type, presence: true, inclusion: { 
    in: %w[bicycle motorcycle car van] 
  }
  validates :license_number, presence: true, uniqueness: true
  validates :current_lat, :current_lng, numericality: true, allow_nil: true
  
  # Performance: Scopes
  scope :available, -> { where(available: true, verified: true) }
  scope :verified, -> { where(verified: true) }
  scope :by_vehicle_type, ->(type) { where(vehicle_type: type) }
  
  # Real-time location tracking
  def update_location!(lat, lng)
    update!(current_lat: lat, current_lng: lng, last_location_update: Time.current)
    
    # Broadcast location to active deliveries
    active_deliveries.each do |delivery|
      ActionCable.server.broadcast(
        "delivery_#{delivery.id}",
        {
          driver_location: { lat: lat, lng: lng },
          timestamp: Time.current.iso8601
        }
      )
    end
  end
  
  def active_deliveries
    deliveries.where(status: ['assigned', 'picked_up', 'en_route'])
  end
  
  def current_location
    return nil unless current_lat && current_lng
    { lat: current_lat, lng: current_lng }
  end
  
  # Performance: Find nearby available drivers
  def self.find_nearby(lat, lng, radius = 5)
    available.where(
      'earth_distance(ll_to_earth(current_lat, current_lng), ll_to_earth(?, ?)) < ?',
      lat, lng, radius * 1000
    ).order(
      'earth_distance(ll_to_earth(current_lat, current_lng), ll_to_earth(?, ?))',
      lat, lng
    )
  end
end
EOF

  # Enhanced Payment model with security
  cat <<EOF > app/models/payment.rb
class Payment < ApplicationRecord
  belongs_to :order
  
  # Security: Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { 
    in: %w[pending processing completed failed refunded] 
  }
  validates :payment_method, presence: true, inclusion: { 
    in: %w[credit_card debit_card paypal apple_pay google_pay] 
  }
  validates :stripe_payment_intent_id, presence: true, uniqueness: true
  
  # Performance: Status enum
  enum status: {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3,
    refunded: 4
  }
  
  # Security: Encrypt sensitive data
  encrypts :stripe_payment_intent_id
  
  # Performance: Scopes
  scope :successful, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { where('created_at > ?', 1.month.ago) }
  
  # Security: Process payment with Stripe
  def process_payment!
    return false unless pending?
    
    begin
      update!(status: 'processing')
      
      # Create Stripe payment intent
      intent = Stripe::PaymentIntent.create({
        amount: (amount * 100).to_i, # Convert to cents
        currency: 'nok',
        metadata: {
          order_id: order.id,
          customer_id: order.user.id
        }
      })
      
      update!(
        stripe_payment_intent_id: intent.id,
        status: 'completed'
      )
      
      # Confirm order after successful payment
      order.update!(status: 'confirmed')
      
      true
    rescue Stripe::StripeError => e
      update!(status: 'failed', failure_reason: e.message)
      Rails.logger.error "Payment failed for order #{order.id}: #{e.message}"
      false
    end
  end
  
  # Security: Process refund
  def process_refund!(reason = nil)
    return false unless completed?
    
    begin
      Stripe::Refund.create({
        payment_intent: stripe_payment_intent_id,
        reason: 'requested_by_customer'
      })
      
      update!(
        status: 'refunded',
        refund_reason: reason,
        refunded_at: Time.current
      )
      
      true
    rescue Stripe::StripeError => e
      Rails.logger.error "Refund failed for payment #{id}: #{e.message}"
      false
    end
  end
end
EOF
}

# Enhanced services for real-time tracking and optimization
setup_enhanced_services() {
  log "Setting up enhanced services for tracking and optimization"
  
  mkdir -p app/services/{delivery,payment,tracking}
  
  # Real-time delivery tracking service
  cat <<EOF > app/services/delivery/tracking_service.rb
module Delivery
  class TrackingService
    include Redis::Objects
    
    def self.assign_driver(order)
      return false unless order.confirmed?
      
      # Find the best available driver
      restaurant = order.restaurant
      drivers = DeliveryDriver.find_nearby(restaurant.lat, restaurant.lng, 10)
      
      return false if drivers.empty?
      
      # Assign to closest available driver
      driver = drivers.first
      
      delivery = Delivery.create!(
        order: order,
        driver: driver,
        status: 'assigned',
        estimated_pickup: Time.current + 15.minutes
      )
      
      # Update order status
      order.update!(status: 'preparing')
      
      # Make driver unavailable
      driver.update!(available: false)
      
      # Send notifications
      DriverAssignmentJob.perform_later(delivery)
      
      delivery
    end
    
    def self.update_delivery_status(delivery, new_status, location = nil)
      old_status = delivery.status
      delivery.update!(status: new_status)
      
      case new_status
      when 'picked_up'
        delivery.update!(pickup_time: Time.current)
        delivery.order.update!(status: 'out_for_delivery')
      when 'delivered'
        delivery.update!(delivery_time: Time.current)
        delivery.order.update!(status: 'delivered')
        delivery.driver.update!(available: true)
      when 'cancelled'
        delivery.driver.update!(available: true)
        delivery.order.update!(status: 'cancelled')
      end
      
      # Update driver location if provided
      if location && delivery.driver
        delivery.driver.update_location!(location[:lat], location[:lng])
      end
      
      # Send real-time updates
      broadcast_delivery_update(delivery)
      
      # Send notifications
      DeliveryStatusNotificationJob.perform_later(delivery, old_status)
    end
    
    def self.calculate_optimal_route(driver, deliveries)
      # Simplified route optimization - in production would use Google Maps API
      locations = deliveries.map do |delivery|
        {
          order_id: delivery.order.id,
          lat: delivery.order.delivery_lat,
          lng: delivery.order.delivery_lng,
          priority: delivery.order.estimated_delivery
        }
      end
      
      # Sort by estimated delivery time for now
      locations.sort_by { |loc| loc[:priority] }
    end
    
    private
    
    def self.broadcast_delivery_update(delivery)
      ActionCable.server.broadcast(
        "order_#{delivery.order.id}",
        {
          delivery_status: delivery.status,
          driver_location: delivery.driver.current_location,
          estimated_delivery: delivery.order.estimated_delivery,
          pickup_time: delivery.pickup_time,
          delivery_time: delivery.delivery_time
        }
      )
    end
  end
end
EOF

  # Payment processing service
  cat <<EOF > app/services/payment/stripe_service.rb
module Payment
  class StripeService
    def self.create_payment_intent(order)
      Stripe::PaymentIntent.create({
        amount: (order.total * 100).to_i, # Convert to cents
        currency: 'nok',
        metadata: {
          order_id: order.id,
          customer_id: order.user.id,
          restaurant_id: order.restaurant.id
        },
        automatic_payment_methods: {
          enabled: true
        }
      })
    end
    
    def self.confirm_payment(payment_intent_id, payment_method_id)
      Stripe::PaymentIntent.confirm(
        payment_intent_id,
        { payment_method: payment_method_id }
      )
    end
    
    def self.create_customer(user)
      Stripe::Customer.create({
        email: user.email,
        name: user.name,
        phone: user.phone,
        metadata: {
          user_id: user.id
        }
      })
    end
    
    def self.process_refund(payment, reason = nil)
      Stripe::Refund.create({
        payment_intent: payment.stripe_payment_intent_id,
        reason: reason || 'requested_by_customer',
        metadata: {
          order_id: payment.order.id,
          refund_reason: reason
        }
      })
    end
  end
end
EOF
}

# Enhanced controllers with security and real-time features
setup_enhanced_controllers() {
  log "Setting up enhanced controllers with security and real-time features"
  
  # Enhanced Orders Controller with payment integration
  cat <<EOF > app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: [:show, :edit, :update, :destroy, :cancel, :track]
  before_action :verify_order_ownership, only: [:show, :edit, :update, :destroy, :cancel]
  
  # Performance: Cache for public tracking
  before_action :set_cache_headers, only: [:track]

  def index
    @pagy, @orders = pagy(
      current_user.orders.includes(:restaurant, :delivery, :payment)
                          .order(created_at: :desc)
    ) unless @stimulus_reflex
  end

  def show
    @tracking_info = @order.tracking_info
  end

  def new
    @restaurant = Restaurant.find(params[:restaurant_id]) if params[:restaurant_id]
    @order = current_user.orders.build(restaurant: @restaurant)
    @cart = session[:cart] || {}
  end

  def create
    @order = current_user.orders.build(order_params)
    @order.status = 'pending'
    
    if @order.save
      # Calculate total from cart items
      add_cart_items_to_order
      @order.calculate_total!
      
      # Generate tracking token
      @order.generate_tracking_token!
      
      # Clear cart
      session[:cart] = {}
      
      respond_to do |format|
        format.html { redirect_to payment_order_path(@order) }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :form_errors }
      end
    end
  end

  def payment
    # Create Stripe payment intent
    begin
      @payment_intent = Payment::StripeService.create_payment_intent(@order)
      
      @payment = @order.build_payment(
        amount: @order.total,
        status: 'pending',
        stripe_payment_intent_id: @payment_intent.id
      )
      @payment.save!
      
    rescue Stripe::StripeError => e
      redirect_to @order, alert: t('takeaway.payment_error', error: e.message)
    end
  end

  def confirm_payment
    begin
      # Confirm payment with Stripe
      payment_intent = Payment::StripeService.confirm_payment(
        params[:payment_intent_id],
        params[:payment_method_id]
      )
      
      if payment_intent.status == 'succeeded'
        payment = Payment.find_by(stripe_payment_intent_id: payment_intent.id)
        payment.update!(status: 'completed')
        
        # Confirm order and assign driver
        payment.order.update!(status: 'confirmed')
        Delivery::TrackingService.assign_driver(payment.order)
        
        redirect_to payment.order, notice: t('takeaway.payment_successful')
      else
        redirect_to payment_order_path(payment.order), alert: t('takeaway.payment_failed')
      end
      
    rescue Stripe::StripeError => e
      redirect_to payment_order_path(@order), alert: t('takeaway.payment_error', error: e.message)
    end
  end

  def cancel
    if @order.can_be_cancelled?
      @order.update!(status: 'cancelled')
      
      # Process refund if payment was completed
      if @order.payment&.completed?
        RefundProcessingJob.perform_later(@order.payment)
      end
      
      redirect_to orders_path, notice: t('takeaway.order_cancelled')
    else
      redirect_to @order, alert: t('takeaway.cannot_cancel_order')
    end
  end

  def track
    # Public tracking endpoint using tracking token
    @order = Order.find_by!(tracking_token: params[:tracking_token])
    @tracking_info = @order.tracking_info
    
    render layout: 'tracking'
  end

  private

  def set_order
    if params[:tracking_token]
      @order = Order.find_by!(tracking_token: params[:tracking_token])
    else
      @order = current_user.orders.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to orders_path, alert: t('takeaway.order_not_found')
  end

  def verify_order_ownership
    unless @order.user == current_user || current_user.admin?
      redirect_to orders_path, alert: t('takeaway.access_denied')
    end
  end

  def order_params
    params.require(:order).permit(
      :restaurant_id, :delivery_address, :delivery_lat, :delivery_lng,
      :special_instructions
    )
  end

  def add_cart_items_to_order
    cart = session[:cart] || {}
    
    cart.each do |menu_item_id, quantity|
      menu_item = MenuItem.find(menu_item_id)
      
      @order.order_items.create!(
        menu_item: menu_item,
        quantity: quantity,
        price: menu_item.price
      )
    end
  end

  def set_cache_headers
    response.headers['Cache-Control'] = 'public, max-age=60' # 1 minute cache
  end
end
EOF
}

# Enhanced background jobs for real-time processing
setup_background_jobs() {
  log "Setting up enhanced background jobs for real-time processing"
  
  mkdir -p app/jobs
  
  # Driver assignment job
  cat <<EOF > app/jobs/driver_assignment_job.rb
class DriverAssignmentJob < ApplicationJob
  queue_as :high_priority

  def perform(delivery)
    # Send notification to driver
    driver = delivery.driver
    order = delivery.order
    
    # Push notification to driver app
    if driver.user.push_token.present?
      PushNotificationService.send_to_driver(
        driver.user.push_token,
        {
          title: 'New Delivery Request',
          body: "Order ##{order.id} from #{order.restaurant.name}",
          data: {
            delivery_id: delivery.id,
            order_id: order.id,
            restaurant_address: order.restaurant.address,
            customer_address: order.delivery_address
          }
        }
      )
    end
    
    # Send email notification
    DriverNotificationMailer.new_assignment(delivery).deliver_now
    
    # Real-time update to driver dashboard
    ActionCable.server.broadcast(
      "driver_#{driver.user.id}",
      {
        type: 'new_assignment',
        delivery: delivery.as_json(include: [:order, :restaurant])
      }
    )
  end
end
EOF

  # Order status notification job
  cat <<EOF > app/jobs/order_status_notification_job.rb
class OrderStatusNotificationJob < ApplicationJob
  queue_as :default

  def perform(order)
    customer = order.user
    
    # Send push notification to customer
    if customer.push_token.present?
      message = status_message(order.status)
      
      PushNotificationService.send_to_customer(
        customer.push_token,
        {
          title: 'Order Update',
          body: message,
          data: {
            order_id: order.id,
            status: order.status,
            tracking_token: order.tracking_token
          }
        }
      )
    end
    
    # Send email notification for important status changes
    if %w[confirmed out_for_delivery delivered].include?(order.status)
      OrderStatusMailer.status_update(order).deliver_now
    end
    
    # Update restaurant dashboard
    ActionCable.server.broadcast(
      "restaurant_#{order.restaurant.id}",
      {
        type: 'order_status_update',
        order_id: order.id,
        status: order.status
      }
    )
  end
  
  private
  
  def status_message(status)
    case status
    when 'confirmed'
      'Your order has been confirmed and is being prepared'
    when 'preparing'
      'Your order is being prepared'
    when 'ready'
      'Your order is ready for pickup'
    when 'out_for_delivery'
      'Your order is on the way!'
    when 'delivered'
      'Your order has been delivered. Enjoy!'
    else
      "Your order status has been updated to #{status.humanize}"
    end
  end
end
EOF
}

# Main execution
main() {
  log "Starting Enhanced Takeaway Platform Setup - Framework v12.3.0"
  
  setup_enhanced_takeaway_app
  generate_enhanced_models
  setup_enhanced_services
  setup_enhanced_controllers
  setup_background_jobs
  
  # Security: Setup payment security
  setup_security_headers
  setup_monitoring
  
  # Performance: Database optimizations
  log "Setting up database optimizations for takeaway platform"
  
  # Add database indexes for performance
  cat <<EOF > db/migrate/add_takeaway_performance_indexes.rb
class AddTakeawayPerformanceIndexes < ActiveRecord::Migration[7.0]
  def change
    # Geospatial indexes
    add_index :restaurants, [:lat, :lng]
    add_index :restaurants, :cuisine_type
    add_index :restaurants, [:verified, :accepting_orders]
    add_index :delivery_drivers, [:current_lat, :current_lng]
    add_index :delivery_drivers, [:available, :verified]
    
    # Order processing indexes
    add_index :orders, [:status, :created_at]
    add_index :orders, [:user_id, :status]
    add_index :orders, [:restaurant_id, :status]
    add_index :orders, :tracking_token, unique: true
    
    # Payment indexes
    add_index :payments, [:status, :created_at]
    add_index :payments, :stripe_payment_intent_id, unique: true
    
    # Delivery tracking indexes
    add_index :deliveries, [:driver_id, :status]
    add_index :deliveries, [:order_id, :status]
    
    # Menu and ordering indexes
    add_index :menu_items, [:restaurant_id, :available, :category]
    add_index :order_items, [:order_id, :menu_item_id]
  end
end
EOF
  
  commit_to_git "Enhanced Takeaway Platform setup complete: Real-time tracking, payment security, performance optimized"
  
  log "Enhanced Takeaway Platform setup complete - Framework v12.3.0"
  log "Features: Real-time tracking, secure payments, driver assignment"
  log "Performance: Optimized queries, caching, background processing"
  log "Security: Payment security, order validation, driver verification"
}

# Execute main function
main "$@"