#!/bin/sh

source "$(dirname "$0")/common.sh"

# Ensure script is executed from the correct directory
cd "$BASE_DIR"

# Run the PWA generator
bin/rails generate pwa:install

# Stage changes and commit them
commit_to_git "Configured Rails to run as a Progressive Web App (PWA)"

