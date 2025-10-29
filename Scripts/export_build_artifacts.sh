#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./Scripts/export_build_artifacts.sh
#
# Environment variables:
#   BUILD_ROOT (optional) - defaults to ./mobile/ios-field-utility
#   OUTPUT_DIR (optional) - defaults to ./REPORTS/build
#
# The script copies the most recent Xcode build logs, derived data dSYMs,
# and xcodebuild reports into REPORTS/build so they can be attached to the
# validation artifacts for A1.3. It is idempotent and safe to run on both
# macOS and CI environments.

BUILD_ROOT="${BUILD_ROOT:-$(pwd)/mobile/ios-field-utility}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/REPORTS/build}"
DERIVED_DATA="${DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData}"

echo "🔧 Exporting build artifacts"
echo "   BUILD_ROOT = ${BUILD_ROOT}"
echo "   OUTPUT_DIR = ${OUTPUT_DIR}"

mkdir -p "${OUTPUT_DIR}"

copy_if_exists() {
  local source="$1"
  local destination="$2"

  if [[ -e "${source}" ]]; then
    echo "   • copying $(basename "${source}")"
    rsync -a "${source}" "${destination}"
  else
    echo "   • skipping $(basename "${source}") (not found)"
  fi
}

copy_latest_build_logs() {
  local log_dir="$1"
  local output="$2"

  if [[ ! -d "${log_dir}" ]]; then
    echo "   • build log directory not found (${log_dir})"
    return
  fi

  local latest
  latest="$(find "${log_dir}" -type f -name '*.xcactivitylog' -print0 | xargs -0 ls -t | head -n 5 || true)"
  if [[ -z "${latest}" ]]; then
    echo "   • no xcactivitylog files discovered"
    return
  fi

  mkdir -p "${output}/xcactivitylog"
  while IFS= read -r log; do
    [[ -z "${log}" ]] && continue
    cp "${log}" "${output}/xcactivitylog/"
  done <<< "${latest}"
}

copy_if_exists "${BUILD_ROOT}/build/reports" "${OUTPUT_DIR}/"
copy_if_exists "${BUILD_ROOT}/build/logs" "${OUTPUT_DIR}/"

copy_latest_build_logs "${DERIVED_DATA}" "${OUTPUT_DIR}"

echo "✅ Export complete. Inspect ${OUTPUT_DIR} for generated artifacts."
