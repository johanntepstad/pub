#!/bin/zsh

source "$(dirname "$0")/common.sh"

# Ensure Redis is installed
if ! command_exists redis-server; then
  echo "Redis is not installed. Installing..."
  doas pkg_add -U redis
  doas rcctl enable redis
  doas rcctl start redis
fi

echo "Redis setup complete."
commit_to_git "Configured Redis"

