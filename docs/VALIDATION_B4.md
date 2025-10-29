# Validation B4 — OTA Heartbeat Persistence

## Steps
1. Started the OTA server and noted the listening port. 【e4b336†L1-L2】
2. Posted a heartbeat for `dev1` and recorded the acknowledgment payload (`REPORTS/B4/ota_persist_before.json`). 【df6dd8†L1-L8】
3. Restarted the service and fetched `/v1/ota/status`, confirming the persisted boot count and version (`REPORTS/B4/ota_persist_after_restart.json`). 【a1cac1†L1-L2】【ff4215†L1-L12】

## PASS Checklist
- [x] Heartbeat accepted with persisted state
- [x] Restart retains latest `bootCount` and `status`
- [ ] Multi-device persistence sweep (follow-up)
