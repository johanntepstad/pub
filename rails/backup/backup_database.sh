#!/bin/bash

# Enhanced database backup script with encryption and monitoring
# Framework v12.3.0 compliant

set -euo pipefail

# Configuration
DB_NAME="${1:-}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/postgresql}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
S3_BUCKET="${S3_BUCKET:-}"
ENCRYPTION_KEY="${ENCRYPTION_KEY:-}"

# Logging
log() {
  echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') - $1" | tee -a "$BACKUP_DIR/backup.log"
}

error() {
  log "ERROR: $1"
  exit 1
}

# Security: Validate inputs
validate_inputs() {
  if [[ -z "$DB_NAME" ]]; then
    error "Database name required. Usage: $0 <database_name>"
  fi
  
  if [[ ! "$DB_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    error "Invalid database name format"
  fi
}

# Security: Check prerequisites
check_prerequisites() {
  command -v pg_dump >/dev/null 2>&1 || error "pg_dump not found"
  command -v gzip >/dev/null 2>&1 || error "gzip not found"
  
  # Check encryption tool
  if [[ -n "$ENCRYPTION_KEY" ]]; then
    command -v gpg >/dev/null 2>&1 || error "gpg required for encryption"
  fi
  
  # Create backup directory
  mkdir -p "$BACKUP_DIR"
  chmod 700 "$BACKUP_DIR"
}

# Performance: Create database backup
create_backup() {
  local timestamp
  timestamp=$(date +"%Y%m%d_%H%M%S")
  local backup_file="$BACKUP_DIR/${DB_NAME}_${timestamp}.sql"
  
  log "Starting backup of database: $DB_NAME"
  
  # Performance: Create compressed backup
  if ! pg_dump --no-password --clean --create --format=custom \
       --compress=9 "$DB_NAME" > "$backup_file.dump"; then
    error "Failed to create database backup"
  fi
  
  # Security: Encrypt backup if key provided
  if [[ -n "$ENCRYPTION_KEY" ]]; then
    log "Encrypting backup..."
    if ! gpg --symmetric --cipher-algo AES256 --compress-algo 2 \
         --passphrase "$ENCRYPTION_KEY" \
         --output "$backup_file.gpg" "$backup_file.dump"; then
      error "Failed to encrypt backup"
    fi
    
    # Security: Remove unencrypted backup
    rm "$backup_file.dump"
    backup_file="$backup_file.gpg"
  else
    mv "$backup_file.dump" "$backup_file.gz"
    gzip "$backup_file"
    backup_file="$backup_file.gz"
  fi
  
  # Security: Set secure permissions
  chmod 600 "$backup_file"
  
  log "Backup created: $backup_file"
  log "Backup size: $(du -h "$backup_file" | cut -f1)"
}

# Performance: Upload to cloud storage
upload_to_cloud() {
  if [[ -z "$S3_BUCKET" ]]; then
    log "No S3 bucket configured, skipping cloud upload"
    return 0
  fi
  
  log "Uploading backup to S3..."
  
  if command -v aws >/dev/null 2>&1; then
    local backup_file="$1"
    local s3_key="postgresql/$(basename "$backup_file")"
    
    if aws s3 cp "$backup_file" "s3://$S3_BUCKET/$s3_key" \
       --storage-class STANDARD_IA; then
      log "Backup uploaded to S3: s3://$S3_BUCKET/$s3_key"
    else
      log "WARNING: Failed to upload backup to S3"
    fi
  else
    log "WARNING: AWS CLI not found, skipping S3 upload"
  fi
}

# Maintenance: Clean old backups
cleanup_old_backups() {
  log "Cleaning up backups older than $RETENTION_DAYS days..."
  
  local deleted_count=0
  while IFS= read -r -d '' file; do
    rm "$file"
    ((deleted_count++))
    log "Deleted old backup: $(basename "$file")"
  done < <(find "$BACKUP_DIR" -name "${DB_NAME}_*.sql*" -mtime +$RETENTION_DAYS -print0)
  
  log "Cleaned up $deleted_count old backup(s)"
}

# Monitoring: Verify backup integrity
verify_backup() {
  local backup_file="$1"
  
  log "Verifying backup integrity..."
  
  if [[ "$backup_file" == *.gpg ]]; then
    # Security: Verify encrypted file
    if gpg --list-packets "$backup_file" >/dev/null 2>&1; then
      log "Encrypted backup integrity verified"
      return 0
    else
      error "Backup integrity check failed"
    fi
  elif [[ "$backup_file" == *.gz ]]; then
    # Performance: Verify compressed file
    if gzip -t "$backup_file"; then
      log "Compressed backup integrity verified"
      return 0
    else
      error "Backup integrity check failed"
    fi
  fi
}

# Monitoring: Send notification
send_notification() {
  local status="$1"
  local backup_file="$2"
  
  if [[ -n "${WEBHOOK_URL:-}" ]]; then
    local message
    if [[ "$status" == "success" ]]; then
      message="✅ Database backup completed successfully: $(basename "$backup_file")"
    else
      message="❌ Database backup failed for database: $DB_NAME"
    fi
    
    curl -X POST "$WEBHOOK_URL" \
         -H "Content-Type: application/json" \
         -d "{\"text\": \"$message\"}" \
         >/dev/null 2>&1 || log "WARNING: Failed to send notification"
  fi
}

# Main execution
main() {
  log "Starting enhanced database backup process"
  
  validate_inputs
  check_prerequisites
  
  local backup_file
  if create_backup; then
    # Get the latest backup file
    backup_file=$(find "$BACKUP_DIR" -name "${DB_NAME}_*.sql*" -newest -print -quit)
    
    verify_backup "$backup_file"
    upload_to_cloud "$backup_file"
    cleanup_old_backups
    send_notification "success" "$backup_file"
    
    log "Database backup process completed successfully"
  else
    send_notification "failure" ""
    error "Database backup process failed"
  fi
}

main "$@"