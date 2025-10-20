#!/bin/sh
set -euo pipefail

if [ -z "${RTSP_URL:-}" ]; then
  echo "[ffmpeg] RTSP_URL environment variable must be set" >&2
  exit 1
fi

OUTPUT_DIR="/hls"
STREAM_NAME="${HLS_STREAM_NAME:-mini}"
SEGMENT_SECONDS="${HLS_SEGMENT_SECONDS:-2}"
WINDOW="${HLS_WINDOW:-6}"

mkdir -p "${OUTPUT_DIR}"

cleanup_old_segments() {
  rm -f "${OUTPUT_DIR}/${STREAM_NAME}.m3u8" "${OUTPUT_DIR}/${STREAM_NAME}"_*.ts 2>/dev/null || true
}

cleanup_old_segments

while true; do
  echo "[ffmpeg] starting pull from ${RTSP_URL}" >&2
  ffmpeg -nostdin -loglevel info \
    -rtsp_transport tcp \
    -i "${RTSP_URL}" \
    -max_delay 5000000 \
    -c:v copy \
    -an \
    -f hls \
    -hls_time "${SEGMENT_SECONDS}" \
    -hls_list_size "${WINDOW}" \
    -hls_flags delete_segments+append_list+omit_endlist \
    -hls_segment_filename "${OUTPUT_DIR}/${STREAM_NAME}_%03d.ts" \
    "${OUTPUT_DIR}/${STREAM_NAME}.m3u8"

  exit_code=$?
  echo "[ffmpeg] process exited with code ${exit_code}, restarting in 5s" >&2
  sleep 5
  cleanup_old_segments
done
