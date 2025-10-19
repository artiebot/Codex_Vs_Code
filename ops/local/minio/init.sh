#!/bin/sh
set -euo pipefail

echo "==> Initializing MinIO for SkyFeeder local dev"

mc alias set local http://minio:9000 "${MINIO_ROOT_USER:-minioadmin}" "${MINIO_ROOT_PASSWORD:-minioadmin}"

# Create separate buckets
for BUCKET in photos clips; do
  if mc ls local/"${BUCKET}" >/dev/null 2>&1; then
    echo "Bucket ${BUCKET} already exists"
  else
    mc mb local/"${BUCKET}"
    echo "Created bucket ${BUCKET}"
  fi
done

# Apply lifecycle rules
mc ilm rule add local/photos --expiry-days 30 2>/dev/null || echo "Lifecycle rule for photos already exists"
mc ilm rule add local/clips --expiry-days 1 2>/dev/null || echo "Lifecycle rule for clips already exists"

echo "==> Bootstrap complete"
mc ls local
