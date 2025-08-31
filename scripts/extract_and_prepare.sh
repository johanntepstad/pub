#!/usr/bin/env bash
# Extract and prepare backup artifacts from anon repository backups, map them into the target repo structure.
# Usage: bash scripts/extract_and_prepare.sh /path/to/working-repo
# Note: This script will NOT overwrite files without creating .merge_conflicts entries.
set -euo pipefail

REPO_DIR="${1:-.}"   # default to current directory
TMPDIR="$(mktemp -d)"
SRC_BASE_RAW="https://raw.githubusercontent.com/anon987654321/pub/main/__OLD_BACKUPS"
FILES_TO_DOWNLOAD=(
  "BRGEN_OLD.zip"
  "__docs_20240804.tgz"
  "openbsd_20240804.tgz"
  "openbsd_20240806.tgz"
  "rails_amber_20240804.tgz"
  "rails_amber_20240806.tgz"
  "rails_brgen_20240804.tgz"
  "rails_brgen_20240806.tgz"
  "rails___shared_20240804.tgz"
  "sh_20240804.tgz"
  "sh_20240806.tgz"
  "MEGA_ALL_BPLANS.md"
  "FINAL_ALL_BUSINESS_PLANS.md"
  "MEGA_ALL_APPS.md"
  "j-dilla-minimal-carousel.html"
  "__docs_20240804.tgz"
  "loose_files_20240804.tgz"
  "loose_files_20240806.tgz"
)

echo "Working in repo dir: ${REPO_DIR}"
echo "Temporary workspace: ${TMPDIR}"
cd "${TMPDIR}"

download() {
  local name="$1"
  local url="${SRC_BASE_RAW}/${name}"
  echo "Downloading ${name}..."
  curl -fSL --retry 3 -o "${name}" "${url}" || {
    echo "Warning: failed to download ${name} (may not exist)"
    return 1
  }
  return 0
}

for f in "${FILES_TO_DOWNLOAD[@]}"; do
  download "${f}" || true
done

# Extract archives found
for archive in *.tgz *.tar.gz *.zip 2>/dev/null || true; do
  [ -f "${archive}" ] || continue
  echo "Extracting ${archive}..."
  case "${archive}" in
    *.tgz|*.tar.gz) mkdir -p "${TMPDIR}/extracted/${archive}"; tar -xzf "${archive}" -C "${TMPDIR}/extracted/${archive}";;
    *.zip) mkdir -p "${TMPDIR}/extracted/${archive}"; unzip -q "${archive}" -d "${TMPDIR}/extracted/${archive}";;
    *) echo "Unknown archive type: ${archive}";;
  esac
done

# Map extracted content into target directories. Do NOT overwrite existing files.
# Mapping rules (adjust as needed):
# - Any extracted path containing "/rails" => ${REPO_DIR}/rails/
# - Any extracted path containing "/sh" or file extension .sh => ${REPO_DIR}/sh/
# - Any extracted path containing "/openbsd" or path "openbsd_*" => ${REPO_DIR}/openbsd/
# - Any ai-related folders (ai3, ai33) => ${REPO_DIR}/ai3/
# - Loose html/md intended as bplans => ${REPO_DIR}/bplans/
#
# This operation preserves existing files: conflicting files are written to .merge_conflicts/

MERGE_CONFLICT_DIR="${REPO_DIR}/.merge_conflicts"
mkdir -p "${MERGE_CONFLICT_DIR}"

find "${TMPDIR}/extracted" -type f 2>/dev/null | while read -r src; do
  rel="${src#${TMPDIR}/extracted/}"
  lower_rel="$(echo "${rel}" | tr '[:upper:]' '[:lower:]')"
  target=""
  if [[ "${lower_rel}" == *"/rails/"* ]] || [[ "${lower_rel}" == rails_* ]]; then
    target="${REPO_DIR}/rails/${rel##*/}"
  elif [[ "${lower_rel}" == *"/openbsd/"* ]] || [[ "${lower_rel}" == openbsd_* ]]; then
    target="${REPO_DIR}/openbsd/${rel##*/}"
  elif [[ "${lower_rel}" == *"/ai3/"* ]] || [[ "${lower_rel}" == "ai33"* ]] || [[ "${lower_rel}" == *"/ai33/"* ]]; then
    target="${REPO_DIR}/ai3/${rel##*/}"
  elif [[ "${rel}" == *.sh ]] || [[ "${lower_rel}" == *"/sh/" ]] ; then
    target="${REPO_DIR}/sh/${rel##*/}"
  elif [[ "${rel}" == *.html ]] || [[ "${rel}" == *.md ]] || [[ "${lower_rel}" == *"bplans"* ]]; then
    target="${REPO_DIR}/bplans/${rel##*/}"
  else
    # fallback to copying into bplans if html/md, otherwise into vendor_imports
    if [[ "${rel}" == *.html ]] || [[ "${rel}" == *.md ]]; then
      target="${REPO_DIR}/bplans/${rel##*/}"
    else
      mkdir -p "${REPO_DIR}/vendor_imports"
      target="${REPO_DIR}/vendor_imports/${rel##*/}"
    fi
  fi

  mkdir -p "$(dirname "${target}")"
  if [ -f "${target}" ]; then
    echo "Conflict: ${target} exists. Saving to ${MERGE_CONFLICT_DIR}/$(basename "${target}").$(date +%s)"
    cp -p "${src}" "${MERGE_CONFLICT_DIR}/$(basename "${target}").$(date +%s)"
  else
    echo "Placing ${rel} -> ${target}"
    cp -p "${src}" "${target}"
    # preserve executable bit if original was executable
    if [ -x "${src}" ]; then chmod +x "${target}"; fi
  fi
 done

# Download specific top-level HTML/MD artifacts from source repo raw
RAW_BASE_BPLANS="https://raw.githubusercontent.com/anon987654321/pub/main"
declare -a DIRECT_FILES=(
  "bplans/syre.html"
  "bplans/syre/syre.html"
  "__OLD_BACKUPS/MEGA_ALL_BPLANS.md"
  "__OLD_BACKUPS/FINAL_ALL_BUSINESS_PLANS.md"
  "__OLD_BACKUPS/MEGA_ALL_APPS.md"
  "__OLD_BACKUPS/j-dilla-minimal-carousel.html"
)

for f in "${DIRECT_FILES[@]}"; do
  url="${RAW_BASE_BPLANS}/${f}"
  out="${REPO_DIR}/bplans/$(basename "${f}")"
  echo "Downloading raw ${f} to ${out}..."
  curl -fSL --retry 3 -o "${out}" "${url}" || {
    echo "Warning: failed to fetch ${url}"
    continue
  }
done

echo "Extraction and placement complete."
echo "Any conflicts were copied to ${MERGE_CONFLICT_DIR}."