# Validation A1.3 — WebSocket Strict Mode

## Steps
1. Launched the relay with `WS_STRICT_VALIDATION=1` and JWT secret `dev-only`. 【5769b2†L1-L5】
2. Sent a 256 KB telemetry payload via a temporary client; connection closed with policy code 1008 as captured in `REPORTS/A1.3/ws_validation_close.txt`. 【16f293†L1-L3】【F:REPORTS/A1.3/ws_validation_close.txt†L1-L1】
3. Queried `/v1/metrics` to verify the oversized drop counter incremented. 【7b1ef6†L1-L17】

## PASS Checklist
- [x] Strict mode enabled with policy close on oversize payload
- [x] Drop metrics incremented after violation
- [ ] Rate-limit scenario (deferred; requires scripted burst)
