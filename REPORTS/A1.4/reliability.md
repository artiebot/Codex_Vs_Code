# A1.4 Reliability & Fault Injection Notes

- Fault injection POST body: `REPORTS/A1.4/faults_command_body.json`
- Response: `REPORTS/A1.4/faults_response.json`
- Upload attempts: see `REPORTS/A1.4/upload_attempts.log` (three successful uploads under fault conditions).
- WebSocket upload-status run log: `REPORTS/A1.4/device_retry_log.txt`.
- WS metrics delta stored in `REPORTS/A1.4/ws_metrics.json` (messageCount increase = $((Get-Content 'REPORTS/A1.4/ws_metrics.json' | ConvertFrom-Json).delta)).

Remaining manual work:
1. Long-duration soak test (>= 24h) with real hardware collecting retry counts and success rate.
2. Power measurements (<200 mAh per event) with INA260 or bench instrument; log to `REPORTS/A1.4/power.csv` + `power_summary.md`.
3. Capture gallery or MinIO screenshots if desired (`REPORTS/A1.4/object.jpg` saved for reference).
