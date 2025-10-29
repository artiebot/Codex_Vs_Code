# Validation A1.1 — Presign API Health Guard

## Steps
1. Started the presign API with dummy MinIO credentials; startup warned about the default JWT secret as expected in dev. 【15f689†L1-L4】
2. Queried `/v1/healthz` and saved the response to `REPORTS/A1.1/healthz_presign.json`, confirming `weakSecret: true` and flag propagation. 【b99b62†L1-L9】

## PASS Checklist
- [x] Presign API process started with guardrails active
- [x] `/v1/healthz` reports `weakSecret: true` in development
- [ ] Discovery/WS/OTA smoke tests (not rerun during this pass)
