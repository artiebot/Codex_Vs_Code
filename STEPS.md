# Phase A (Local Stack)
[x] Ensure local stack uses updated bucket split (`photos`, `clips`) via `docker compose up -d` and rerun `docker compose up -d minio-init` if buckets vanish.
[x] presign-api env vars now live in `ops/local/docker-compose.yml`; adjust overrides there when swapping endpoints or credentials.
[x] A0.4 OTA Smoke via OTA_BASE (A/B + rollback logs)
[x] A1.1 Local VOD MVP (ram retry queue, upload badges, scripts)
[x] A1.2 Discovery v0.2 + Day Index + WS resilience (local)
[x] A1.3 iOS Gallery LOCAL profile (playback + Save to Photos)
[x] A1.4 Reliability & Power (local soak, success =90%)

# Cloud Flip Gates (after A1.4)
[ ] CF-1 Cloudflare Worker + DO + R2 (50-event success =90%)
[ ] CF-2 Apple Dev + APNs/TestFlight (100 pushes, delivery =90%)

# Phase B placeholder
[x] B1 Provisioning (triple power-cycle + captive portal)
[ ] B2 Live WHIP?HLS prototype (defer until CF-2 signed off)

