#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${R2_BUCKET:-}" ]]; then
  echo "R2_BUCKET environment variable required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIFECYCLE="${ROOT_DIR}/backend/r2_lifecycle.json"

if [[ ! -f "${LIFECYCLE}" ]]; then
  echo "Lifecycle file not found at ${LIFECYCLE}" >&2
  exit 1
fi

echo "Applying lifecycle policy to bucket ${R2_BUCKET}..."
aws s3api put-bucket-lifecycle-configuration \
  --bucket "${R2_BUCKET}" \
  --lifecycle-configuration "file://${LIFECYCLE}"

echo "Lifecycle applied."
