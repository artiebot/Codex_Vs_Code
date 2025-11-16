# Backend Validation Results - A1.3.5

## 2025-11-09

### GET /api/health
- Stack started via `docker compose up -d --build` (ops/local)
- Validation command:
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:8080/api/health?deviceId=dev1" | ConvertTo-Json -Depth 8
  ```
- Result snapshot:
  ```json
  {
    "status": "healthy",
    "services": {
      "minio": { "status": "healthy", "latencyMs": 409 },
      "wsRelay": { "status": "healthy", "latencyMs": 20 }
    },
    "storage": {
      "photos": { "count": 64, "totalBytes": 8385177 },
      "videos": { "count": 0, "totalBytes": 0 },
      "freeSpaceBytes": 1022276280320
    },
    "metrics": {
      "weight": { "visitsToday": 0, "sourceDay": "2025-10-30" },
      "visits": { "totalEvents": 1, "lastEventTs": "2025-10-30T01:56:34Z" }
    }
  }
  ```
- ✅ Confirms endpoint online, reports storage stats, visit metrics, and service health for `dev1`.

### GET /api/photos
- Command:
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:8080/api/photos?deviceId=dev1&limit=5" | ConvertTo-Json -Depth 6
  ```
- Result: returned 5 newest files (timestamps normalized, proxy URLs under `/gallery/dev1/photo/<file>`), `total=58` reflecting stored assets.
- Error-path check: `Invoke-RestMethod -Uri "http://localhost:8080/api/photos"` → 400 `device_id_required` (as expected).

### GET /api/videos
- Command:
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:8080/api/videos?deviceId=dev1&limit=5" | ConvertTo-Json -Depth 6
  ```
- Result: local dataset has no clips so response shows `total=0`, `videos=[]` while still returning 200.
- Note: URLs point at new `/gallery/:deviceId/video/:filename` proxy which streams from the `clips` bucket once populated.
### GET /api/settings
- Command:
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:8080/api/settings?deviceId=dev1" | ConvertTo-Json -Depth 4
  ```
- Result: returned persisted settings (defaults on first run, then updated values incl. `updatedAt`).

### POST /api/settings
- Command:
  ```powershell
  Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/settings" -ContentType 'application/json' -Body '{"deviceId":"dev1","settings":{"weightThreshold":75,"cooldownSeconds":600,"cameraEnabled":false}}' | ConvertTo-Json -Depth 4
  ```
- Result: success payload with normalized values + `updatedAt` timestamp. Follow-up GET confirmed persistence.
- Error-path check: posting `{ "weightThreshold":0 }` returns HTTP 400 `invalid_settings`.

### POST /api/trigger/manual
- Command:
  ```powershell
  Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/trigger/manual" -ContentType 'application/json' -Body '{"deviceId":"dev1"}' | ConvertTo-Json -Depth 4
  ```
- Result: `{ "success": true, "websocket": { "attempted": true, "delivered": true } }` verifying relay broadcast path end-to-end.

### POST /api/snapshot
- Command:
  ```powershell
  Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/snapshot" -ContentType 'application/json' -Body '{"deviceId":"dev1"}' | ConvertTo-Json -Depth 4
  ```
- Result: snapshot command acknowledged with the same WebSocket delivery metadata.

### POST /api/cleanup/photos
- Command (non-destructive verification):
  ```powershell
  Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/cleanup/photos" -ContentType 'application/json' -Body '{"deviceId":"dev-test"}' | ConvertTo-Json -Depth 4
  ```
- Result: `deleted=0` (test device has no data) with WS toast emitted; confirms endpoint runs safely even when no files exist.

### POST /api/cleanup/videos
- Command:
  ```powershell
  Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/cleanup/videos" -ContentType 'application/json' -Body '{"deviceId":"dev-test"}' | ConvertTo-Json -Depth 4
  ```
- Result: same semantics as photo cleanup (0 objects deleted, broadcast success message).

### GET /camera/stream
- Command:
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:8080/camera/stream"
  ```
- Result: returns HTTP 503 with `{ "error": "camera_unavailable" }` because `CAMERA_STREAM_URL` is not configured; endpoint ready to proxy once a feed is provided.

### GET /api/logs
- Command:
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:8080/api/logs?services=presign-api,ws-relay&lines=10"
  ```
- Result: plain-text bundle containing captured presign-api request logs plus docker-compose output when available (ws-relay section notes `compose_file_missing` inside container).

### Local Stack Smoke Tests (2025-11-09)
- Verified containers: `docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"` (presign-api, ws-relay, minio, ota-server all healthy).
- HTTP probes:
  - `curl -i http://localhost:8080/healthz` → 200 JSON payload with env metadata.
  - `curl -i "http://localhost:8080/api/health?deviceId=dev1"` → 200 with service/storage metrics (minio + ws-relay healthy).
  - `curl -i "http://localhost:8080/api/photos?deviceId=dev1&limit=3"` → 200 with newest photo URLs.
  - `curl -i "http://localhost:8080/api/videos?deviceId=dev1&limit=3"` → 200 empty array (no local clips yet).
  - `curl -i http://localhost:8080/camera/stream` → 503 `camera_unavailable` (expected until `CAMERA_STREAM_URL` is configured).
  - `curl -i http://localhost:8081/healthz` → 200 `{"ok":true,"rooms":[]}` from ws-relay.
  - `curl -i http://localhost:9180/healthz` → 200 `{"ok":true,"firmwareStatus":[]}` from ota-server.
