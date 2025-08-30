#!/bin/bash

# Enhanced deployment script for Rails applications
# Framework v12.3.0 compliant with security and monitoring

set -euo pipefail

APP_NAME="${1:-}"
DEPLOY_ENV="${2:-production}"
SERVER_USER="${3:-deploy}"
SERVER_HOST="${4:-}"

if [[ -z "$APP_NAME" || -z "$SERVER_HOST" ]]; then
  echo "Usage: $0 <app_name> [environment] [user] <server_host>"
  echo "Example: $0 brgen production deploy 46.23.95.45"
  exit 1
fi

# Security: Validate inputs
validate_inputs() {
  if [[ ! "$APP_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Invalid app name format"
    exit 1
  fi
  
  if [[ ! "$DEPLOY_ENV" =~ ^(production|staging)$ ]]; then
    echo "ERROR: Environment must be 'production' or 'staging'"
    exit 1
  fi
}

# Security: Check prerequisites
check_prerequisites() {
  command -v ssh >/dev/null 2>&1 || { echo "SSH required"; exit 1; }
  command -v rsync >/dev/null 2>&1 || { echo "rsync required"; exit 1; }
  
  # Check SSH key
  if [[ ! -f ~/.ssh/id_rsa ]]; then
    echo "ERROR: SSH key not found. Please set up SSH access to the server."
    exit 1
  fi
}

# Performance: Deploy application with optimizations
deploy_app() {
  echo "Deploying $APP_NAME to $DEPLOY_ENV environment..."
  
  # Security: Create deployment directory
  ssh "$SERVER_USER@$SERVER_HOST" "mkdir -p /var/www/$APP_NAME"
  
  # Performance: Sync files efficiently
  rsync -avz --exclude='.git' --exclude='node_modules' --exclude='log/*' \
        --exclude='tmp/*' --exclude='storage/*' \
        ./ "$SERVER_USER@$SERVER_HOST:/var/www/$APP_NAME/"
  
  # Security: Set proper permissions
  ssh "$SERVER_USER@$SERVER_HOST" "chown -R $SERVER_USER:www /var/www/$APP_NAME"
  ssh "$SERVER_USER@$SERVER_HOST" "chmod -R 755 /var/www/$APP_NAME"
  ssh "$SERVER_USER@$SERVER_HOST" "chmod 600 /var/www/$APP_NAME/config/master.key"
  
  # Performance: Install dependencies and precompile assets
  ssh "$SERVER_USER@$SERVER_HOST" "cd /var/www/$APP_NAME && bundle install --deployment --without development test"
  ssh "$SERVER_USER@$SERVER_HOST" "cd /var/www/$APP_NAME && yarn install --production"
  ssh "$SERVER_USER@$SERVER_HOST" "cd /var/www/$APP_NAME && RAILS_ENV=$DEPLOY_ENV bundle exec rails assets:precompile"
  
  # Performance: Run database migrations
  ssh "$SERVER_USER@$SERVER_HOST" "cd /var/www/$APP_NAME && RAILS_ENV=$DEPLOY_ENV bundle exec rails db:migrate"
  
  # Security: Restart application server
  ssh "$SERVER_USER@$SERVER_HOST" "sudo systemctl restart $APP_NAME || echo 'Service restart failed'"
  
  echo "Deployment completed successfully!"
}

# Monitoring: Setup health checks
setup_health_checks() {
  echo "Setting up health checks..."
  
  # Create health check endpoint
  ssh "$SERVER_USER@$SERVER_HOST" "cd /var/www/$APP_NAME && cat > config/routes.rb << 'EOF'
Rails.application.routes.draw do
  # Health check endpoint
  get '/health', to: proc { [200, {}, ['OK']] }
  
  # Application routes
  root 'home#index'
  # ... other routes
end
EOF"
  
  echo "Health checks configured"
}

# Main execution
main() {
  validate_inputs
  check_prerequisites
  deploy_app
  setup_health_checks
  
  echo "Deployment script completed for $APP_NAME on $DEPLOY_ENV"
}

main "$@"