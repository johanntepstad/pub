#!/bin/zsh

source "$(dirname "$0")/common.sh"

# Ensure PostgreSQL is installed
if ! command_exists psql; then
  echo "PostgreSQL is not installed. Installing..."
  doas pkg_add -U postgresql-server
fi

# Set up PostgreSQL roles and databases
createuser -s ${APP}_user || echo "Role ${APP}_user already exists."
createdb ${APP}_development || echo "Database ${APP}_development already exists."
createdb ${APP}_test || echo "Database ${APP}_test already exists."
createdb ${APP}_production || echo "Database ${APP}_production already exists."

# Create config/database.yml if it doesn't exist
if [ ! -f config/database.yml ]; then
  cat <<EOF > config/database.yml
default: &default
  adapter: postgresql
  encoding: unicode
  username: ${APP}_user
  password: password
  host: localhost
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: ${APP}_development

test:
  <<: *default
  database: ${APP}_test

production:
  <<: *default
  database: ${APP}_production
EOF
else
  echo "config/database.yml already exists."
fi

echo "PostgreSQL setup complete."
commit_to_git "Configured PostgreSQL"

