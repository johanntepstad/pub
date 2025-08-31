APP="amber"
BASE_DIR="$HOME/rails/$APP"

# Function to commit to git
commit_to_git() {
  git add -A
  git commit -m "$1"
  echo "$1"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Function to check if a file exists
check_file_exists() {
  if [ ! -f "$1" ]; then
    echo "File $1 does not exist. Exiting..."
    exit 1
  fi
}

