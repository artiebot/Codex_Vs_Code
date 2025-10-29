#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <deviceId> [--rate 0.25] [--code 500] [--minutes 5] [--api http://localhost:8080]" >&2
  exit 1
fi

DEVICE="$1"
shift

RATE=0.25
CODE=500
MINUTES=5
API_BASE="http://localhost:8080"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rate)
      RATE="$2"
      shift 2
      ;;
    --code)
      CODE="$2"
      shift 2
      ;;
    --minutes)
      MINUTES="$2"
      shift 2
      ;;
    --api)
      API_BASE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

UNTIL_TS=$(($(date +%s) + MINUTES*60))

curl -s -X POST "${API_BASE}/v1/test/faults" \
  -H "Content-Type: application/json" \
  -d "{\"deviceId\":\"${DEVICE}\",\"failPutRate\":${RATE},\"httpCode\":${CODE},\"untilTs\":${UNTIL_TS}}" \
  | jq .
