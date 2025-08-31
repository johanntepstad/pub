#!/bin/zsh

source "$(dirname "$0")/common.sh"

# Ensure Yarn is installed
if ! command_exists yarn; then
  echo "Yarn is not installed. Installing..."
  doas pkg_add -U node
  doas npm install yarn -g
fi

echo "Yarn setup complete."
commit_to_git "Configured Yarn"

