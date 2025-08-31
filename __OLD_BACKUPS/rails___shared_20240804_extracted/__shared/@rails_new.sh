#!/bin/zsh

source "$(dirname "$0")/common.sh"

# Generate the Rails app
if [ ! -d $BASE_DIR ]; then
  gem install bundler --user-install
  gem install rails --user-install

  bundle config set --local path "$HOME/.local"

  rails33 new $APP --database=postgresql --javascript=esbuild --css=sass --assets=propshaft

  cd $APP
  git init
  bundle install
  yarn install

  commit_to_git "Initial commit: Generate Rails app with PostgreSQL, Esbuild, SASS, and Propshaft.
"
fi

cd $BASE_DIR

echo "Rails app setup complete."
commit_to_git "Generated Rails app"

