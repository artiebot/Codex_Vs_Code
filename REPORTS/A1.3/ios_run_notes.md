# iOS LOCAL Gallery Validation Notes

Manual validation is still required to satisfy the A1.3 gallery DoD.

1. Build the iOS LOCAL profile pointing at the current local stack (`API_BASE`, `WS_URL`, `S3_PHOTOS_BASE`, `S3_CLIPS_BASE`).
2. Trigger an upload from the ESP32/Mini path so `event.upload_status` messages appear (see `REPORTS/A1.3/ws_capture.json` for the demo sequence).
3. Confirm the gallery tiles update in real time, Save to Photos succeeds, and the 24h success badge reflects the final `success` status.
4. Capture a short screen recording and place it at `REPORTS/A1.3/gallery_recording.mp4` when available.
