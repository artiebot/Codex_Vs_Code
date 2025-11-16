# Backend Endpoints Test Plan - A1.3.5

**Phase:** A1.3.5 - iOS Dashboard Polish
**Component:** presign-api backend endpoints
**Date:** 2025-11-09
**Author:** Claude Code

---

## Overview

This test plan covers 11 new endpoints to be added to `ops/local/presign-api/src/index.js` to support the iOS dashboard features.

### Design Principles

1. **Small, additive changes only** - Do not modify existing endpoints
2. **Production-ready** - No mock data, use real MinIO/service data
3. **Error handling** - All endpoints return proper HTTP status codes
4. **Consistent format** - JSON responses with clear error messages
5. **ISO8601 dates** - All dates formatted WITHOUT milliseconds

---

## Endpoints to Implement

### 1. GET /camera/stream

**Purpose:** Proxy live camera stream from AMB82-Mini

**Request:**
```bash
GET /camera/stream
```

**Response:**
- Success (200): Stream of image/mjpeg or HLS manifest
- Error (503): Camera unavailable

**Implementation Notes:**
- For MVP: Return 503 with message (camera integration not yet wired)
- Headers: `Content-Type: image/mjpeg` or `application/vnd.apple.mpegurl`
- Cache-Control: `no-cache, no-store, must-revalidate`

**Test Cases:**
```bash
# TC1: Request stream (expect 503 for MVP)
curl -i http://localhost:8080/camera/stream

# Expected: HTTP/1.1 503 Service Unavailable
# Expected body: {"error": "camera_unavailable", "message": "Live stream not yet configured"}
```

---

### 2. GET /api/photos

**Purpose:** List recent photos with proxy URLs

**Request:**
```bash
GET /api/photos?deviceId=dev1&limit=20
```

**Query Parameters:**
- `deviceId` (required): Device identifier
- `limit` (optional): Max photos to return (default: 20, max: 100)

**Response:**
```json
{
  "photos": [
    {
      "filename": "2025-10-30T01-56-34-417Z-h50dKV.jpg",
      "url": "http://10.0.0.4:8080/gallery/dev1/photo/2025-10-30T01-56-34-417Z-h50dKV.jpg",
      "timestamp": "2025-10-30T01:56:34Z",
      "sizeBytes": 5835,
      "type": "photo"
    }
  ],
  "total": 57
}
```

**Test Cases:**
```bash
# TC1: List photos for dev1
curl -i "http://localhost:8080/api/photos?deviceId=dev1&limit=10"

# TC2: Missing deviceId (expect 400)
curl -i "http://localhost:8080/api/photos"

# TC3: Invalid deviceId (expect 200 with empty array)
curl -i "http://localhost:8080/api/photos?deviceId=nonexistent"

# TC4: Limit boundary (expect capped at 100)
curl -i "http://localhost:8080/api/photos?deviceId=dev1&limit=500"
```

---

### 3. GET /api/videos

**Purpose:** List recent clips with proxy URLs

**Request:**
```bash
GET /api/videos?deviceId=dev1&limit=20
```

**Query Parameters:**
- `deviceId` (required): Device identifier
- `limit` (optional): Max videos to return (default: 20, max: 100)

**Response:**
```json
{
  "videos": [
    {
      "filename": "2025-10-30T01-56-34-417Z-abc123.mp4",
      "url": "http://10.0.0.4:8080/gallery/dev1/video/2025-10-30T01-56-34-417Z-abc123.mp4",
      "timestamp": "2025-10-30T01:56:34Z",
      "sizeBytes": 125000,
      "type": "clip"
    }
  ],
  "total": 3
}
```

**Test Cases:**
```bash
# TC1: List videos for dev1
curl -i "http://localhost:8080/api/videos?deviceId=dev1&limit=10"

# TC2: Missing deviceId (expect 400)
curl -i "http://localhost:8080/api/videos"

# TC3: Empty result (no videos)
curl -i "http://localhost:8080/api/videos?deviceId=dev1"
```

---

### 4. GET /api/health

**Purpose:** System health + MinIO stats

**Request:**
```bash
GET /api/health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-11-09T12:34:56Z",
  "uptime": 123456,
  "services": {
    "minio": {
      "status": "healthy",
      "endpoint": "http://minio:9000"
    },
    "ws-relay": {
      "status": "healthy",
      "endpoint": "http://10.0.0.4:8081"
    }
  },
  "storage": {
    "photos": {
      "count": 57,
      "totalBytes": 332145
    },
    "videos": {
      "count": 3,
      "totalBytes": 375000
    },
    "freeSpaceBytes": 104857600
  },
  "metrics": {
    "weight": {
      "current": 0,
      "average": 0,
      "visitsToday": 0
    }
  }
}
```

**Test Cases:**
```bash
# TC1: Health check
curl -i http://localhost:8080/api/health

# Expected: HTTP/1.1 200 OK
# Expected: JSON with all sections
```

---

### 5. GET /api/settings

**Purpose:** Get current device settings

**Request:**
```bash
GET /api/settings?deviceId=dev1
```

**Response:**
```json
{
  "deviceId": "dev1",
  "settings": {
    "weightThreshold": 50,
    "cooldownSeconds": 300,
    "cameraEnabled": true
  }
}
```

**Test Cases:**
```bash
# TC1: Get settings for dev1
curl -i "http://localhost:8080/api/settings?deviceId=dev1"

# TC2: Missing deviceId (expect 400)
curl -i "http://localhost:8080/api/settings"
```

---

### 6. POST /api/settings

**Purpose:** Update device settings

**Request:**
```bash
POST /api/settings
Content-Type: application/json

{
  "deviceId": "dev1",
  "settings": {
    "weightThreshold": 75,
    "cooldownSeconds": 600
  }
}
```

**Response:**
```json
{
  "success": true,
  "deviceId": "dev1",
  "settings": {
    "weightThreshold": 75,
    "cooldownSeconds": 600,
    "cameraEnabled": true
  }
}
```

**Validation:**
- `weightThreshold`: integer, 1-500 grams
- `cooldownSeconds`: integer, 60-3600 seconds

**Test Cases:**
```bash
# TC1: Update settings
curl -i -X POST http://localhost:8080/api/settings \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"dev1","settings":{"weightThreshold":75}}'

# TC2: Invalid threshold (expect 400)
curl -i -X POST http://localhost:8080/api/settings \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"dev1","settings":{"weightThreshold":999}}'

# TC3: Missing deviceId (expect 400)
curl -i -X POST http://localhost:8080/api/settings \
  -H "Content-Type: application/json" \
  -d '{"settings":{"weightThreshold":75}}'
```

---

### 7. POST /api/trigger/manual

**Purpose:** Manually trigger camera capture

**Request:**
```bash
POST /api/trigger/manual
Content-Type: application/json

{
  "deviceId": "dev1"
}
```

**Response:**
```json
{
  "success": true,
  "deviceId": "dev1",
  "message": "Manual trigger sent"
}
```

**Side Effects:**
- Broadcasts WebSocket event to ws-relay: `{"type":"trigger","deviceId":"dev1","source":"manual"}`

**Test Cases:**
```bash
# TC1: Manual trigger
curl -i -X POST http://localhost:8080/api/trigger/manual \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"dev1"}'

# TC2: Missing deviceId (expect 400)
curl -i -X POST http://localhost:8080/api/trigger/manual \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

### 8. POST /api/snapshot

**Purpose:** Capture snapshot immediately

**Request:**
```bash
POST /api/snapshot
Content-Type: application/json

{
  "deviceId": "dev1"
}
```

**Response:**
```json
{
  "success": true,
  "deviceId": "dev1",
  "message": "Snapshot command sent"
}
```

**Side Effects:**
- Broadcasts WebSocket event to ws-relay: `{"type":"snapshot","deviceId":"dev1","source":"manual"}`

**Test Cases:**
```bash
# TC1: Snapshot
curl -i -X POST http://localhost:8080/api/snapshot \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"dev1"}'

# TC2: Missing deviceId (expect 400)
curl -i -X POST http://localhost:8080/api/snapshot \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

### 9. POST /api/cleanup/photos

**Purpose:** Delete all photos for device

**Request:**
```bash
POST /api/cleanup/photos
Content-Type: application/json

{
  "deviceId": "dev1"
}
```

**Response:**
```json
{
  "success": true,
  "deviceId": "dev1",
  "deleted": 57,
  "message": "Deleted 57 photos"
}
```

**Test Cases:**
```bash
# TC1: Delete all photos (WARNING: destructive)
curl -i -X POST http://localhost:8080/api/cleanup/photos \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"dev1"}'

# TC2: Missing deviceId (expect 400)
curl -i -X POST http://localhost:8080/api/cleanup/photos \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

### 10. POST /api/cleanup/videos

**Purpose:** Delete all videos for device

**Request:**
```bash
POST /api/cleanup/videos
Content-Type: application/json

{
  "deviceId": "dev1"
}
```

**Response:**
```json
{
  "success": true,
  "deviceId": "dev1",
  "deleted": 3,
  "message": "Deleted 3 videos"
}
```

**Test Cases:**
```bash
# TC1: Delete all videos (WARNING: destructive)
curl -i -X POST http://localhost:8080/api/cleanup/videos \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"dev1"}'
```

---

### 11. GET /api/logs

**Purpose:** Download system logs

**Request:**
```bash
GET /api/logs?services=presign-api,ws-relay&lines=500
```

**Query Parameters:**
- `services` (optional): Comma-separated list (default: all)
- `lines` (optional): Lines per service (default: 300, max: 1000)

**Response:**
- Content-Type: `text/plain`
- Body: Combined logs from Docker services

**Test Cases:**
```bash
# TC1: Download all logs
curl -i "http://localhost:8080/api/logs"

# TC2: Specific services
curl -i "http://localhost:8080/api/logs?services=presign-api"

# TC3: Limited lines
curl -i "http://localhost:8080/api/logs?lines=100"
```

---

## Test Execution Plan

### Phase 1: Setup
1. Ensure Docker stack is running: `docker compose up -d`
2. Verify existing endpoints work: `curl http://localhost:8080/healthz`
3. Check MinIO has test data: `docker exec skyfeeder-minio mc ls local/photos/dev1/ --recursive`

### Phase 2: Implementation Order
1. **GET /api/health** - Foundation (no dependencies)
2. **GET /api/photos** - Uses MinIO (build on existing patterns)
3. **GET /api/videos** - Similar to photos
4. **GET /api/settings** - Simple state management
5. **POST /api/settings** - Validation + persistence
6. **POST /api/trigger/manual** - WebSocket integration
7. **POST /api/snapshot** - Similar to trigger
8. **POST /api/cleanup/photos** - Destructive operation
9. **POST /api/cleanup/videos** - Similar to photos cleanup
10. **GET /camera/stream** - Stub for future
11. **GET /api/logs** - Docker integration

### Phase 3: Testing
- Test each endpoint immediately after implementation
- Verify responses match expected format
- Check error cases (400, 404, 500)
- Validate side effects (WebSocket events, MinIO changes)

### Phase 4: Documentation
- Update `ops/local/README.md` with all new endpoints
- Document in `ARCHITECTURE.md`
- Record test results in `REPORTS/A1.3.5/backend_validation_results.md`

---

## Success Criteria

- [ ] All 11 endpoints implemented
- [ ] All test cases pass
- [ ] No regression in existing endpoints
- [ ] Docker stack remains stable
- [ ] Documentation updated
- [ ] WebSocket events verified (trigger/snapshot)
- [ ] MinIO operations verified (cleanup)

---

## Risk Mitigation

**Risk:** Destructive cleanup operations
**Mitigation:** Test with backup data first, add confirmation in iOS UI

**Risk:** WebSocket broadcast failures
**Mitigation:** Graceful degradation if ws-relay unavailable

**Risk:** MinIO connection errors
**Mitigation:** Proper error handling with 503 responses

---

## Notes

- Settings persistence: Use in-memory Map for MVP (reset on restart)
- Camera stream: Return 503 stub until camera integration complete
- Logs: Use Docker exec to fetch logs (no auth required in local dev)
- All dates: ISO8601 without milliseconds (Swift compatibility)

---

**Next Steps:**
1. Implement endpoints in order listed above
2. Test each endpoint with curl
3. Document results
4. Update README.md
5. Move to iOS infrastructure phase
