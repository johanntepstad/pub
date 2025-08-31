# Ensure script is executed from the correct directory
cd "$(dirname "$0")/../${APP}"

if ! psql -U dev -d ${APP}_development -c "SELECT to_regclass('public.active_storage_blobs');" | grep -q 'active_storage_blobs'; then
  bin/rails active_storage:install
  bin/rails db:migrate
  bundle add image_processing
  commit_to_git "Set up Active Storage and ImageProcessing."
else
  echo "Active Storage tables already exist, skipping migration."
fi
