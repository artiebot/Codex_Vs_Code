#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <device-id> <config-file> [ota-server-url]" >&2
  exit 1
fi

DEVICE_ID="$1"
CONFIG_FILE="$2"
SERVER_URL="${3:-http://localhost:9180}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

CONFIG_JSON=$(python3 - <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
try:
    payload = json.loads(path.read_text())
except Exception as exc:  # pylint: disable=broad-except
    print(f"failed to parse JSON: {exc}", file=sys.stderr)
    sys.exit(1)
print(json.dumps(payload))
PY
"$CONFIG_FILE")

if [[ -z "$CONFIG_JSON" ]]; then
  echo "Failed to serialize config payload" >&2
  exit 1
fi

RESPONSE=$(curl -sS -X POST \
  "$SERVER_URL/v1/ota/config" \
  -H "Content-Type: application/json" \
  -d "{\"deviceId\":\"$DEVICE_ID\",\"config\":$CONFIG_JSON}")

if [[ $? -ne 0 ]]; then
  echo "OTA staging request failed" >&2
  exit 1
fi

echo "$RESPONSE"
