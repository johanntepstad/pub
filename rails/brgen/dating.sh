#!/bin/bash

#!/usr/bin/env zsh
set -euo pipefail  # Enhanced error handling

# Enhanced Dating platform setup: Location-based dating with advanced matchmaking
# Framework v12.3.0 compliant with security hardening and performance optimizations
# Security improvements: Input validation, rate limiting, profile verification
# Performance enhancements: Geospatial queries, caching, real-time matching

APP_NAME="brgen_dating"
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

log "Starting Enhanced Dating Platform Setup - Framework v12.3.0"

# Enhanced setup with security validation
setup_enhanced_dating_app() {
  log "Setting up enhanced dating application with security features"
  setup_full_app "$APP_NAME"
  
  # Performance: Install geospatial and optimization gems
  log "Installing dating-specific gems with security focus"
  install_gem "geokit-rails" "~> 2.5"
  install_gem "geocoder" "~> 1.8"
  install_gem "image_processing" "~> 1.2"
  install_gem "redis-rails" "~> 5.0"
  
  # Security: Additional security gems
  install_gem "recaptcha" "~> 5.12"
  install_gem "rack-attack" "~> 6.7"
  install_gem "devise-security" "~> 0.18"
}

# Enhanced models with security and performance
generate_enhanced_models() {
  log "Generating enhanced models with security and performance features"
  
  # Performance: Generate models with proper indexes
  bin/rails generate model Profile user:references bio:text location:string lat:decimal lng:decimal gender:string age:integer interests:text verified:boolean last_active:datetime
  bin/rails generate model Match initiator:references receiver:references status:string matched_at:datetime
  bin/rails generate model Dating::Like user:references liked_user:references created_at:datetime
  bin/rails generate model Dating::Dislike user:references disliked_user:references created_at:datetime
  bin/rails generate model Dating::Block blocker:references blocked_user:references reason:string
  bin/rails generate model Dating::Report reporter:references reported_user:references reason:string description:text status:string
  
  # Security: Enhanced Profile model with validations
  cat <<EOF > app/models/profile.rb
class Profile < ApplicationRecord
  belongs_to :user
  has_many_attached :photos
  has_many :initiated_matches, class_name: 'Match', foreign_key: 'initiator_id', dependent: :destroy
  has_many :received_matches, class_name: 'Match', foreign_key: 'receiver_id', dependent: :destroy
  
  # Geospatial capabilities
  include Geokit::Geocoders
  acts_as_mappable default_units: :kms, lat_column_name: :lat, lng_column_name: :lng
  
  # Security: Comprehensive validations
  validates :bio, presence: true, length: { in: 10..1000 }
  validates :location, presence: true, length: { maximum: 200 }
  validates :lat, :lng, presence: true, numericality: true
  validates :gender, presence: true, inclusion: { in: %w[male female non-binary other] }
  validates :age, presence: true, numericality: { 
    greater_than_or_equal_to: 18, 
    less_than_or_equal_to: 99 
  }
  validates :interests, length: { maximum: 500 }
  
  # Security: Photo validation
  validates :photos, attached: true, content_type: ['image/png', 'image/jpg', 'image/jpeg'],
            size: { less_than: 5.megabytes }
  validate :photos_limit
  
  # Performance: Scopes for common queries
  scope :active, -> { where('last_active > ?', 1.week.ago) }
  scope :verified, -> { where(verified: true) }
  scope :by_age_range, ->(min, max) { where(age: min..max) }
  scope :by_gender, ->(gender) { where(gender: gender) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Performance: Geospatial search
  scope :within_radius, ->(lat, lng, radius = 50) {
    within(radius, origin: [lat, lng])
  }
  
  # Security: Profile verification
  def verify!
    update!(verified: true)
    ProfileVerificationMailer.verified(self).deliver_later
  end
  
  def update_last_active!
    update_column(:last_active, Time.current)
  end
  
  # Performance: Cached distance calculation
  def distance_to(other_profile)
    Rails.cache.fetch("distance:#{id}:#{other_profile.id}", expires_in: 1.hour) do
      distance_from([other_profile.lat, other_profile.lng])
    end
  end
  
  # Security: Block and report functionality
  def blocked_by?(user)
    Dating::Block.exists?(blocker: user, blocked_user: self.user)
  end
  
  def reported_by?(user)
    Dating::Report.exists?(reporter: user, reported_user: self.user)
  end
  
  private
  
  def photos_limit
    errors.add(:photos, 'maximum 6 photos allowed') if photos.count > 6
  end
end
EOF

  # Enhanced matching service with security and performance
  mkdir -p app/services/dating
  cat <<EOF > app/services/dating/enhanced_matchmaking_service.rb
module Dating
  class EnhancedMatchmakingService
    include Redis::Objects
    
    def self.find_matches(user)
      return [] unless user.profile
      
      # Security: Update last active timestamp
      user.profile.update_last_active!
      
      # Performance: Use cached results when possible
      cache_key = "matches:#{user.id}:#{Date.current}"
      Rails.cache.fetch(cache_key, expires_in: 4.hours) do
        perform_matching(user)
      end
    end

    def self.perform_matching(user)
      profile = user.profile
      return [] unless profile
      
      # Security: Get blocked and reported users
      blocked_ids = Dating::Block.where(blocker: user).pluck(:blocked_user_id)
      blocking_ids = Dating::Block.where(blocked_user: user).pluck(:blocker_id)
      reported_ids = Dating::Report.where(reporter: user).pluck(:reported_user_id)
      
      # Performance: Exclude already interacted users
      excluded_ids = [user.id] + blocked_ids + blocking_ids + reported_ids
      excluded_ids += user.dating_likes.pluck(:liked_user_id)
      excluded_ids += user.dating_dislikes.pluck(:disliked_user_id)
      excluded_ids += existing_match_user_ids(user)
      
      # Performance: Build optimized query
      potential_matches = Profile.includes(:user, photos_attachments: :blob)
                                 .joins(:user)
                                 .where.not(user_id: excluded_ids)
                                 .where(gender: compatible_genders(profile.gender))
                                 .verified
                                 .active
                                 .within_radius(profile.lat, profile.lng, 100) # 100km radius
                                 .by_age_range(profile.age - 10, profile.age + 10)
                                 .limit(20)
      
      # Performance: Score and sort matches
      score_matches(profile, potential_matches)
    end

    def self.score_matches(profile, potential_matches)
      matches_with_scores = potential_matches.map do |match|
        score = calculate_compatibility_score(profile, match)
        { profile: match, score: score }
      end
      
      # Return top matches sorted by score
      matches_with_scores.sort_by { |m| -m[:score] }
                        .first(10)
                        .map { |m| m[:profile] }
    end

    def self.calculate_compatibility_score(profile1, profile2)
      score = 0
      
      # Distance factor (closer is better, max 25 points)
      distance = profile1.distance_to(profile2)
      distance_score = [25 - (distance * 0.5), 0].max
      score += distance_score
      
      # Age compatibility (max 20 points)
      age_diff = (profile1.age - profile2.age).abs
      age_score = [20 - age_diff, 0].max
      score += age_score
      
      # Interest similarity (max 30 points)
      interest_score = calculate_interest_similarity(profile1, profile2)
      score += interest_score
      
      # Activity factor (max 15 points)
      activity_score = profile2.last_active > 3.days.ago ? 15 : 5
      score += activity_score
      
      # Verification bonus (max 10 points)
      verification_score = profile2.verified? ? 10 : 0
      score += verification_score
      
      score
    end

    def self.calculate_interest_similarity(profile1, profile2)
      return 0 if profile1.interests.blank? || profile2.interests.blank?
      
      interests1 = profile1.interests.downcase.split(',').map(&:strip)
      interests2 = profile2.interests.downcase.split(',').map(&:strip)
      
      common_interests = interests1 & interests2
      return 0 if common_interests.empty?
      
      # Calculate Jaccard similarity
      union_size = (interests1 | interests2).size
      similarity = common_interests.size.to_f / union_size
      
      (similarity * 30).round
    end

    private

    def self.compatible_genders(user_gender)
      case user_gender
      when 'male' then %w[female non-binary]
      when 'female' then %w[male non-binary]
      when 'non-binary' then %w[male female non-binary other]
      when 'other' then %w[male female non-binary other]
      else %w[male female non-binary other]
      end
    end

    def self.existing_match_user_ids(user)
      Match.where(
        "(initiator_id = ? OR receiver_id = ?) AND status IN (?)",
        user.profile.id, user.profile.id, %w[pending matched]
      ).includes(:initiator, :receiver)
       .map { |m| m.initiator.user_id == user.id ? m.receiver.user_id : m.initiator.user_id }
    end
  end
end
EOF

  # Security: Block and report models
  cat <<EOF > app/models/dating/block.rb
module Dating
  class Block < ApplicationRecord
    belongs_to :blocker, class_name: 'User'
    belongs_to :blocked_user, class_name: 'User'
    
    validates :blocker_id, uniqueness: { scope: :blocked_user_id }
    validates :reason, presence: true, length: { maximum: 500 }
    validate :cannot_block_self
    
    private
    
    def cannot_block_self
      errors.add(:blocked_user, "cannot block yourself") if blocker_id == blocked_user_id
    end
  end
end
EOF

  cat <<EOF > app/models/dating/report.rb
module Dating
  class Report < ApplicationRecord
    belongs_to :reporter, class_name: 'User'
    belongs_to :reported_user, class_name: 'User'
    
    validates :reason, presence: true, inclusion: { 
      in: %w[inappropriate harassment fake spam underage other] 
    }
    validates :description, presence: true, length: { in: 10..1000 }
    validates :status, inclusion: { in: %w[pending reviewed resolved] }
    
    scope :pending, -> { where(status: 'pending') }
    scope :by_reason, ->(reason) { where(reason: reason) }
    
    after_create :notify_moderators
    
    private
    
    def notify_moderators
      ModerationMailer.new_report(self).deliver_later
    end
  end
end
EOF
}

# Enhanced controllers with security
setup_enhanced_controllers() {
  log "Setting up enhanced controllers with security features"
  
  # Enhanced Profiles Controller with rate limiting
  cat <<EOF > app/controllers/profiles_controller.rb
class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_profile, only: [:show, :edit, :update, :destroy, :like, :dislike, :block, :report]
  before_action :check_rate_limit, only: [:like, :dislike]
  before_action :verify_recaptcha, only: [:create, :update], unless: :skip_recaptcha?
  
  # Performance: Cache for public pages
  before_action :set_cache_headers, only: [:index, :show]

  def index
    # Performance: Use enhanced matchmaking service
    @profiles = Dating::EnhancedMatchmakingService.find_matches(current_user)
    @pagy, @profiles = pagy(@profiles) unless @stimulus_reflex
    
    # Performance: Preload for map display
    @map_profiles = @profiles.limit(50).map do |profile|
      {
        id: profile.id,
        user_email: profile.user.email,
        bio: profile.bio.truncate(100),
        lat: profile.lat,
        lng: profile.lng,
        verified: profile.verified?
      }
    end
  end

  def show
    # Security: Check if user is blocked
    if @profile.blocked_by?(current_user)
      redirect_to profiles_path, alert: t("dating.user_blocked")
      return
    end
    
    # Performance: Track profile view
    ProfileViewJob.perform_later(@profile, current_user) if current_user != @profile.user
  end

  def new
    @profile = current_user.build_profile
  end

  def create
    @profile = current_user.build_profile(profile_params)
    
    if @profile.save
      # Security: Send verification email
      ProfileVerificationMailer.welcome(@profile).deliver_later
      
      respond_to do |format|
        format.html { redirect_to @profile, notice: t("dating.profile_created") }
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
    if @profile.update(profile_params)
      respond_to do |format|
        format.html { redirect_to @profile, notice: t("dating.profile_updated") }
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
    @profile.destroy
    
    respond_to do |format|
      format.html { redirect_to root_path, notice: t("dating.profile_deleted") }
      format.turbo_stream
    end
  end

  def like
    # Security: Rate limiting is handled by before_action
    like = Dating::Like.find_or_create_by(
      user: current_user,
      liked_user: @profile.user
    )
    
    # Performance: Check for mutual like asynchronously
    CheckMutualLikeJob.perform_later(current_user, @profile.user)
    
    respond_to do |format|
      format.html { redirect_to profiles_path, notice: t("dating.like_sent") }
      format.turbo_stream { render :like_response }
    end
  end

  def dislike
    Dating::Dislike.find_or_create_by(
      user: current_user,
      disliked_user: @profile.user
    )
    
    respond_to do |format|
      format.html { redirect_to profiles_path }
      format.turbo_stream { render :dislike_response }
    end
  end

  def block
    Dating::Block.create!(
      blocker: current_user,
      blocked_user: @profile.user,
      reason: params[:reason] || 'No reason provided'
    )
    
    redirect_to profiles_path, notice: t("dating.user_blocked_successfully")
  end

  def report
    Dating::Report.create!(
      reporter: current_user,
      reported_user: @profile.user,
      reason: params[:reason],
      description: params[:description]
    )
    
    redirect_to profiles_path, notice: t("dating.report_submitted")
  end

  private

  def set_profile
    @profile = Profile.includes(:user, photos_attachments: :blob).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to profiles_path, alert: t("dating.profile_not_found")
  end

  def profile_params
    params.require(:profile).permit(
      :bio, :location, :lat, :lng, :gender, :age, :interests, 
      photos: []
    )
  end

  def check_rate_limit
    # Security: Limit likes/dislikes per hour
    key = "profile_actions:#{current_user.id}:#{1.hour.ago.to_i}"
    count = Rails.cache.read(key) || 0
    
    if count >= 100 # 100 actions per hour
      respond_to do |format|
        format.html { redirect_to profiles_path, alert: t("dating.rate_limit_exceeded") }
        format.turbo_stream { render :rate_limit_error }
      end
      return false
    end
    
    Rails.cache.write(key, count + 1, expires_in: 1.hour)
  end

  def verify_recaptcha
    return if Rails.env.development? || Rails.env.test?
    
    unless verify_recaptcha(action: 'profile')
      respond_to do |format|
        format.html { 
          flash.now[:alert] = t("dating.recaptcha_failed")
          render action_name.to_sym, status: :unprocessable_entity 
        }
        format.turbo_stream { render :recaptcha_error }
      end
      return false
    end
  end

  def skip_recaptcha?
    current_user.profile&.verified? || Rails.env.test?
  end

  def set_cache_headers
    return if user_signed_in?
    
    response.headers['Cache-Control'] = 'public, max-age=300'
  end
end
EOF
}

# Enhanced background jobs
setup_background_jobs() {
  log "Setting up enhanced background jobs for performance"
  
  mkdir -p app/jobs
  
  # Performance: Async match checking
  cat <<EOF > app/jobs/check_mutual_like_job.rb
class CheckMutualLikeJob < ApplicationJob
  queue_as :default

  def perform(user1, user2)
    # Check if both users liked each other
    if Dating::Like.exists?(user: user1, liked_user: user2) &&
       Dating::Like.exists?(user: user2, liked_user: user1)
      
      # Create match
      match = Match.find_or_create_by(
        initiator: user1.profile,
        receiver: user2.profile
      ) do |m|
        m.status = 'matched'
        m.matched_at = Time.current
      end
      
      if match.persisted?
        # Send notifications
        MatchNotificationMailer.new_match(match).deliver_now
        
        # Real-time notification via ActionCable
        ActionCable.server.broadcast(
          "user_#{user1.id}",
          { type: 'new_match', match_id: match.id }
        )
        ActionCable.server.broadcast(
          "user_#{user2.id}",
          { type: 'new_match', match_id: match.id }
        )
      end
    end
  end
end
EOF

  # Performance: Profile view tracking
  cat <<EOF > app/jobs/profile_view_job.rb
class ProfileViewJob < ApplicationJob
  queue_as :low_priority

  def perform(profile, viewer)
    return if profile.user == viewer
    
    # Track view for analytics
    Rails.cache.increment("profile_views:#{profile.id}", 1, expires_in: 1.day)
    
    # Store recent viewers (limited to last 10)
    recent_viewers_key = "recent_viewers:#{profile.id}"
    recent_viewers = Rails.cache.read(recent_viewers_key) || []
    recent_viewers = recent_viewers.reject { |v| v[:user_id] == viewer.id }
    recent_viewers.unshift({
      user_id: viewer.id,
      viewed_at: Time.current.iso8601
    })
    recent_viewers = recent_viewers.first(10)
    
    Rails.cache.write(recent_viewers_key, recent_viewers, expires_in: 1.week)
  end
end
EOF
}

# Enhanced mailers
setup_mailers() {
  log "Setting up enhanced mailers for notifications"
  
  mkdir -p app/mailers
  
  cat <<EOF > app/mailers/match_notification_mailer.rb
class MatchNotificationMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_FROM', 'noreply@datingapp.com')

  def new_match(match)
    @match = match
    @initiator = match.initiator
    @receiver = match.receiver
    
    mail(
      to: [@initiator.user.email, @receiver.user.email],
      subject: t('dating.mailer.new_match_subject')
    )
  end
end
EOF

  cat <<EOF > app/mailers/profile_verification_mailer.rb
class ProfileVerificationMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_FROM', 'noreply@datingapp.com')

  def welcome(profile)
    @profile = profile
    @user = profile.user
    
    mail(
      to: @user.email,
      subject: t('dating.mailer.welcome_subject')
    )
  end

  def verified(profile)
    @profile = profile
    @user = profile.user
    
    mail(
      to: @user.email,
      subject: t('dating.mailer.verification_complete_subject')
    )
  end
end
EOF
}

# Main execution
main() {
  log "Starting Enhanced Dating Platform Setup - Framework v12.3.0"
  
  setup_enhanced_dating_app
  generate_enhanced_models
  setup_enhanced_controllers
  setup_background_jobs
  setup_mailers
  
  # Security: Setup additional security features
  setup_security_headers
  setup_monitoring
  
  # Performance: Database optimizations
  log "Setting up database optimizations"
  
  # Add database indexes for performance
  cat <<EOF > db/migrate/add_performance_indexes.rb
class AddPerformanceIndexes < ActiveRecord::Migration[7.0]
  def change
    # Geospatial indexes
    add_index :profiles, [:lat, :lng]
    add_index :profiles, :location
    
    # Performance indexes
    add_index :profiles, [:gender, :age, :verified, :last_active]
    add_index :profiles, :last_active
    add_index :profiles, :verified
    
    # Relationship indexes
    add_index :dating_likes, [:user_id, :liked_user_id], unique: true
    add_index :dating_dislikes, [:user_id, :disliked_user_id], unique: true
    add_index :dating_blocks, [:blocker_id, :blocked_user_id], unique: true
    add_index :dating_reports, [:reporter_id, :reported_user_id]
    
    # Match indexes
    add_index :matches, [:initiator_id, :receiver_id, :status]
    add_index :matches, :matched_at
  end
end
EOF
  
  commit_to_git "Enhanced Dating Platform setup complete: Security hardened, performance optimized"
  
  log "Enhanced Dating Platform setup complete - Framework v12.3.0"
  log "Features: Advanced matchmaking, geospatial search, security hardening"
  log "Performance: Optimized queries, caching, background processing"
  log "Security: Rate limiting, content moderation, user verification"
}

# Execute main function
main "$@"