# SkyFeeder System Architecture

_Last updated: 2025-11-09_

**DO NOT DEVIATE FROM THIS ARCHITECTURE WITHOUT EXPLICIT APPROVAL**

This document defines the core architecture, technology stack, design patterns, and constraints for the SkyFeeder project. All development must align with these specifications.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Component Architecture](#component-architecture)
3. [Technology Stack](#technology-stack)
4. [Data Flows](#data-flows)
5. [Design Decisions & Constraints](#design-decisions--constraints)
6. [File Organization](#file-organization)
7. [Key Patterns](#key-patterns)
8. [Security Model](#security-model)

---

## System Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (Swift)                         │
│  - Gallery View (photo browsing)                                │
│  - WebSocket connection for real-time updates                   │
│  - Badge notifications                                           │
└─────────────┬───────────────────────────────────┬───────────────┘
              │                                   │
              │ HTTP(S)                          │ WebSocket
              ▼                                   ▼
┌─────────────────────────────┐   ┌─────────────────────────────┐
│    presign-api (Node.js)    │   │    ws-relay (Node.js)       │
│  - Gallery manifest serving │   │  - Real-time telemetry      │
│  - Photo proxy              │   │  - Upload status broadcast  │
│  - Presigned URL generation │   │  - Device rooms (JWT)       │
│  - Discovery endpoint       │   │  - Queue/replay on reconnect│
│  - Day index writer         │   └─────────────────────────────┘
│  - Fault injection          │
└──────────────┬──────────────┘
               │
               │ S3 API
               ▼
┌─────────────────────────────┐   ┌─────────────────────────────┐
│      MinIO (S3 storage)     │   │   ota-server (Node.js)      │
│  - photos bucket (30d TTL)  │   │  - Firmware file hosting    │
│  - clips bucket (1d TTL)    │   │  - Heartbeat API            │
│  - Day indices              │   │  - Rollback tracking        │
└─────────────────────────────┘   └─────────────────────────────┘
               ▲
               │ HTTP PUT
               │
┌──────────────┴──────────────┐
│     ESP32 Controller        │
│  - Photo upload manager     │
│  - WebSocket client         │
│  - Retry queue (3 attempts) │
│  - OTA update client        │
└─────────────┬───────────────┘
              │ UART
              ▼
┌─────────────────────────────┐
│    AMB82-Mini (Camera)      │
│  - Photo capture            │
│  - Deep sleep mgmt          │
│  - GPIO wake                │
└─────────────────────────────┘
```

### Deployment Model

**Current Phase:** Local-first (Option A)
- All services run on LAN via Docker Compose
- No cloud dependencies (Cloudflare, R2)
- MinIO replaces cloud S3
- Local WebSocket relay instead of cloud broker

**Future Phase:** Cloud-enabled (CF-1, CF-2)
- Cloudflare Workers + Durable Objects
- R2 storage
- APNs for push notifications
- **Note:** Cloud flip is GATED until local phases complete

---

## Component Architecture

### 1. MinIO (S3-Compatible Storage)

**Purpose:** Object storage for photos, clips, and day indices

**Buckets:**
```
photos/
  <deviceId>/
    <timestamp>-<id>.jpg              # Photo files
    indices/day-YYYY-MM-DD.json       # Daily manifest files

clips/
  <deviceId>/
    <timestamp>-<id>.mp4              # Video clips
```

**Lifecycle Rules:**
- `photos`: 30-day retention
- `clips`: 1-day retention

**Configuration:**
- Port 9200: S3 API
- Port 9201: Web Console
- Default credentials: `minioadmin:minioadmin` (local dev only)
- Path: `ops/local/docker-compose.yml`

### 2. presign-api (Node.js/Express)

**Purpose:** Central API gateway for gallery, presigning, discovery, and day indices

**Key Endpoints:**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/healthz` | GET | Health check |
| `/v1/discovery/:deviceId` | GET | Device configuration |
| `/v1/presign/put` | POST | Generate presigned upload URL |
| `/gallery/:deviceId/indices/latest.json` | GET | Latest gallery manifest |
| `/gallery/:deviceId/captures_index.json` | GET | Legacy gallery manifest (fallback) |
| `/gallery/:deviceId/photo/:filename` | GET | Photo proxy (streams from MinIO) |
| `/api/telemetry` | GET | Latest telemetry snapshot per device |
| `/api/telemetry/push` | POST | ESP32 telemetry push (pack voltage, watts, RSSI, weight) |

**Environment Variables:**
```bash
S3_ENDPOINT=http://minio:9000
S3_REGION=us-east-1
S3_BUCKET_PHOTOS=photos
S3_BUCKET_CLIPS=clips
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
PUBLIC_BASE=http://10.0.0.4:8080
GALLERY_BUCKET=photos
GALLERY_PREFIX=                    # Empty - photos at root of bucket
MINIO_ENDPOINT=http://minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
```

**Key Features:**
- Gallery manifest transformation (day index → iOS format)
- Photo proxy pattern (avoids presigned URL signature issues)
- Fault injection for testing
- Day index auto-generation on upload
- ISO8601 date formatting (without milliseconds for Swift)
- In-memory telemetry cache fed by ESP32 HTTP pushes

**Path:** `ops/local/presign-api/`

### 3. ws-relay (Node.js/WebSocket)

**Purpose:** Real-time telemetry relay with device rooms

**Features:**
- JWT-protected rooms keyed by `deviceId`
- Message injection: adds `deviceId` and `ts` to all messages
- Queue/replay on reconnect (4-second buffer)
- Upload status broadcast to iOS clients
- Metrics endpoint at `/v1/metrics`

**Message Types:**
- `ping/pong`: Heartbeat
- `upload_status`: Photo upload progress (queued → uploading → success/failed)
- `gallery_ack`: Gallery refresh notification

**Port:** 8081

**Path:** `ops/local/ws-relay/`

### 4. ota-server (Node.js/Express)

**Purpose:** Firmware file hosting and OTA update coordination

**Endpoints:**
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/healthz` | GET | Health check |
| `/fw/:version/:filename` | GET | Firmware file download |
| `/v1/ota/heartbeat` | POST | Device boot reporting |
| `/v1/ota/status` | GET | OTA status for all devices |

**Features:**
- Static file serving from `public/fw/`
- SHA-256 verification
- Rollback detection
- Boot count tracking

**Port:** 9180

**Path:** `ops/local/ota-server/`

### 5. ESP32 Firmware

**Purpose:** Device controller and communication hub

**Control Plane (canonical):**
- Local-only HTTP/WS control plane; **no MQTT is required at runtime**. MQTT helpers remain as legacy stubs to avoid large refactors but do not establish network connections.

**Responsibilities:**
- Photo upload management with retry queue (1min, 5min, 15min)
- Capture session state machine (PIR+weight gating, `capture_start` at T+0s, 5 s clip at T+5s, then photos every 15 s until departure or 10-photo cap)
- UART control of AMB82-Mini camera (wake pulses, capture sequencing, deep-sleep)
- OTA update client with rollback support and boot health tracking
- Telemetry push via HTTP (`POST /api/telemetry/push`) with pack/solar/load power, weight, and RSSI every 30 s
- Wi-Fi provisioning + non-blocking connection state machine with NVS-backed failure counters
- Task watchdog + periodic maintenance reboot for self-recovery

**Key Files:**
- `skyfeeder/config.h`: Configuration constants (Wi-Fi, watchdog, maintenance reboot)
- `skyfeeder/skyfeeder.ino`: Main entrypoint, watchdog + maintenance reboot policy
- `skyfeeder/provisioning.cpp`: Captive portal, Wi-Fi config, failure counters, triple power-cycle handling
- `skyfeeder/mqtt_client.cpp`: Wi-Fi connection state machine (legacy MQTT transport stub)
- `skyfeeder/telemetry_service.cpp`: HTTP telemetry push loop (`/api/telemetry/push`, 30 s cadence)
- `skyfeeder/command_handler.cpp`: Command routing + AMB82 sequencing and recovery (with degraded-mode handling)
- `skyfeeder/mini_link.cpp`: UART framing, wake pulses, power control for AMB82-Mini

**Upload Retry Pattern:**
```
Attempt 1: Immediate
Attempt 2: +1 minute
Attempt 3: +5 minutes
Attempt 4: +15 minutes (max)
```

### 6. AMB82-Mini Firmware

**Purpose:** Camera capture and deep sleep management

**Responsibilities:**
- Photo capture (JPEG encoding)
- Session-aware command handling for `capture_start`, `capture_photo`, and `capture_stop`
- Video clip recording (5 s MJPEG AVI in PSRAM) + `queueClipUpload` for `clip.mp4`
- UART communication with ESP32
- Deep sleep when idle
- GPIO wake on trigger
- 800ms warm-up delay before capture

**Key Files:**
- `amb-mini/amb-mini.ino`: Main loop and UART handler
- Wake-to-ready time: ~10 seconds

### 7. iOS App (Swift/SwiftUI)

**Purpose:** User interface for gallery browsing and device monitoring

**Architecture:**
- SwiftUI views
- Provider pattern for data sources
- Disk cache for thumbnails/assets
- WebSocket client for real-time updates

**Key Components:**

| Component | Purpose |
|-----------|---------|
| `PresignedCaptureProvider` | Fetches gallery manifests from API |
| `DiskCache` | Local caching (thumbnails, assets) |
| `GalleryView` | Photo grid display |
| `DetailView` | Full-size photo viewer |
| `OfflineBannerView` | Network status indicator |
| `BadgeManager` | App badge for new captures |

**Settings:**
- Base URL: `http://10.0.0.4:8080/gallery`
- Device ID: `dev1` (default: `field-kit-1`)

**Paths:**
- `mobile/ios-field-utility/SkyFeederFieldUtility/`
- `mobile/ios-field-utility/SkyFeederUI/`

---

## Technology Stack

### Backend Services

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| presign-api | Node.js + Express | 18+ | API gateway |
| ws-relay | Node.js + WebSocket | 18+ | Real-time relay |
| ota-server | Node.js + Express | 18+ | Firmware hosting |
| MinIO | Go (binary) | latest | S3 storage |
| Docker | Compose v2 | v3.9 | Orchestration |

### Firmware

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| ESP32 | Arduino Core | ESP-IDF | Controller |
| AMB82-Mini | Arduino Core | - | Camera |
| UART | Serial3 @ 115200 | - | ESP32 ↔ Mini |

### Mobile

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| iOS App | Swift | 5+ | UI |
| UI Framework | SwiftUI | iOS 17+ | Views |
| Networking | URLSession | - | HTTP client |
| WebSocket | URLSessionWebSocketTask | - | Real-time |
| Decoder | JSONDecoder | - | JSON parsing |

### Development Tools

| Tool | Purpose |
|------|---------|
| PowerShell | Scripting (Windows) |
| Mosquitto CLI | MQTT testing |
| curl | API testing |
| wscat | WebSocket testing |
| esptool | Firmware flashing |
| Xcode | iOS builds |

---

## Data Flows

### Photo Upload Flow

```
1. ESP32 receives trigger (PIR/weight sensor)
2. ESP32 sends UART wake command to AMB82-Mini
3. AMB82-Mini wakes from deep sleep (~10s)
4. AMB82-Mini waits 800ms for camera warm-up
5. AMB82-Mini captures Photo #1 immediately and streams JPEG bytes to ESP32 for upload
6. ESP32 schedules a 5-second video clip (AMB82 records MJPEG AVI in PSRAM, then `queueClipUpload`) and requests additional photos every 15 seconds while the bird remains (up to 10 total or 150 s)
7. For each photo/clip, ESP32 requests a presigned URL from presign-api
8. presign-api generates S3 presigned URL + Authorization header
9. ESP32 uploads media to MinIO using the presigned URL
10. presign-api updates day index file in MinIO
11. ESP32 broadcasts upload_status via WebSocket
12. iOS app receives gallery_ack via WebSocket
13. iOS app fetches updated manifest from presign-api
14. iOS app displays new photo/video in gallery
```

### Gallery Manifest Flow

```
1. iOS app requests manifest: GET /gallery/dev1/indices/latest.json
2. presign-api lists all dev1/indices/day-*.json files in MinIO
3. presign-api selects newest day index
4. presign-api fetches day index content
5. presign-api transforms day index to gallery manifest format:
   - events[] → captures[]
   - Add id, title, capturedAt fields
   - Generate proxy URLs (not presigned URLs)
   - Format dates as ISO8601 without milliseconds
6. presign-api returns manifest: { "captures": [...] }
7. iOS app parses manifest with JSONDecoder (iso8601 strategy)
8. iOS app displays photos in grid
```

### Photo Download Flow

```
1. iOS app requests photo: GET /gallery/dev1/photo/<filename>.jpg
2. presign-api constructs MinIO object key: dev1/<filename>.jpg
3. presign-api fetches photo from MinIO using S3Client
4. presign-api streams photo bytes to iOS app
5. iOS app caches photo in DiskCache
6. iOS app displays photo in UI
```

**Why photo proxy instead of presigned URLs?**
- MinIO signature verification fails with port forwarding (9000→9200)
- AWS signatures include hostname - changing it breaks verification
- Proxy pattern is simpler and more reliable for local development

### WebSocket Telemetry Flow

```
1. ESP32 connects to ws://10.0.0.4:8081?token=<JWT>
2. ws-relay validates JWT and assigns to deviceId room
3. ESP32 sends upload_status messages (queued, uploading, success, etc.)
4. ws-relay injects deviceId and ts fields
5. ws-relay broadcasts to all clients in deviceId room
6. iOS app receives upload_status
7. iOS app updates badge count
8. iOS app sends gallery_ack back to ws-relay
9. ws-relay broadcasts gallery_ack to ESP32
```

### OTA Update Flow

```
1. ESP32 polls /v1/discovery/dev1 for fw_version
2. If new version available, ESP32 downloads from OTA_BASE
3. ESP32 verifies SHA-256 hash
4. ESP32 applies update to inactive partition
5. ESP32 reboots into new partition
6. ESP32 sends heartbeat to /v1/ota/heartbeat
7. ota-server tracks boot success
8. If boot fails, ESP32 rollback to previous partition
```

---

## Design Decisions & Constraints

### Core Principles

1. **Local-first architecture**: All services run on LAN, no cloud dependencies
2. **S3-compatible storage**: MinIO for local, R2 for cloud (future)
3. **WebSocket for real-time**: Persistent connection, not polling
4. **Retry with backoff**: All network operations retry with exponential backoff
5. **Fail-safe defaults**: Graceful degradation, never crash on network errors

### Critical Constraints

#### 1. Photo Proxy Pattern (DO NOT CHANGE)

**Rule:** Always use photo proxy endpoint `/gallery/:deviceId/photo/:filename`

**Rationale:**
- Presigned URLs fail with port forwarding (9000→9200)
- AWS signature verification includes hostname
- Proxy pattern is simpler and more reliable

**Implementation:**
```javascript
// ✅ CORRECT: Use photo proxy
const photoUrl = `${PUBLIC_BASE}/gallery/${deviceId}/photo/${filename}`;

// ❌ WRONG: Generate presigned URL
const presignedUrl = await getSignedUrl(s3Client, new GetObjectCommand({...}));
```

#### 2. Date Format for Swift (DO NOT CHANGE)

**Rule:** Always format dates as ISO8601 WITHOUT milliseconds

**Rationale:**
- Swift's ISO8601DateDecoder expects format: `2025-10-30T01:56:34Z`
- Format WITH milliseconds (`2025-10-30T01:56:34.417Z`) causes decode failure

**Implementation:**
```javascript
// ✅ CORRECT: Remove milliseconds
const capturedAt = timestampMatch[1].replace(/T(\d{2})-(\d{2})-(\d{2})/, 'T$1:$2:$3') + 'Z';

// ❌ WRONG: Include milliseconds
const capturedAt = new Date().toISOString(); // 2025-10-30T01:56:34.417Z
```

#### 3. Gallery Manifest Format (DO NOT CHANGE)

**Rule:** Always return `{ "captures": [...] }` format

**Rationale:**
- iOS `PresignedCaptureProvider` expects specific schema
- Day index format `{ "events": [...] }` is internal storage format
- Transformation is required

**Required Fields:**
```javascript
{
  "captures": [
    {
      "id": "uuid",
      "title": "filename.jpg",
      "capturedAt": "2025-10-30T01:56:34Z",  // ISO8601, no milliseconds
      "duration": null,
      "fileSizeBytes": 5835,
      "thumbnailURL": "http://10.0.0.4:8080/gallery/dev1/photo/filename.jpg",
      "assetURL": "http://10.0.0.4:8080/gallery/dev1/photo/filename.jpg",
      "contentType": "image/jpeg"
    }
  ]
}
```

#### 4. GALLERY_PREFIX Must Be Empty (DO NOT CHANGE)

**Rule:** `GALLERY_PREFIX` environment variable must be empty string

**Rationale:**
- Photos are stored at `dev1/...` in MinIO (no prefix)
- Setting `GALLERY_PREFIX=photos` causes API to look for `photos/dev1/...`
- Results in 404 errors

**Configuration:**
```yaml
# docker-compose.yml
environment:
  GALLERY_BUCKET: photos
  GALLERY_PREFIX: ""  # ✅ EMPTY - photos are at root of bucket
```

#### 5. Upload Retry Pattern (DO NOT CHANGE)

**Rule:** 3 retry attempts with exponential backoff

**Schedule:**
- Attempt 1: Immediate
- Attempt 2: +1 minute
- Attempt 3: +5 minutes
- Attempt 4: +15 minutes (final)

**Rationale:**
- Network flakiness is common in field deployments
- Exponential backoff reduces server load
- 15-minute max prevents indefinite queue growth

#### 6. WebSocket Reconnect Strategy (DO NOT CHANGE)

**Rule:** Exponential backoff with queue/replay

**Behavior:**
- Disconnect detected: queue all messages
- Reconnect attempts: 1s, 2s, 4s, 8s, 16s (max)
- On reconnect: replay queued messages in order
- Max queue size: 100 messages

#### 7. Day Index File Naming (DO NOT CHANGE)

**Rule:** `day-YYYY-MM-DD.json` format in `<deviceId>/indices/` folder

**Example:**
```
photos/
  dev1/
    indices/
      day-2025-10-29.json
      day-2025-10-30.json
      day-2025-11-09.json
```

**Rationale:**
- One file per day for efficient querying
- ISO date format for lexicographic sorting
- Indices folder separates metadata from photos

#### 8. MinIO Port Mapping (DO NOT CHANGE)

**Rule:** Internal port 9000, external port 9200

**Rationale:**
- Avoids conflict with macOS AirPlay Receiver (port 7000)
- Consistent with existing docker-compose configuration
- All hardcoded references use 9200

**Configuration:**
```yaml
# docker-compose.yml
services:
  minio:
    ports:
      - "9200:9000"  # S3 API
      - "9201:9001"  # Web Console
```

---

## File Organization

### Repository Structure

```
feeder-project/
├── ops/
│   └── local/                          # Local Docker stack
│       ├── docker-compose.yml          # Service orchestration
│       ├── README.md                   # Setup + troubleshooting docs
│       ├── presign-api/                # Gallery + presign API
│       │   ├── src/index.js           # Main API server
│       │   ├── Dockerfile
│       │   └── package.json
│       ├── ws-relay/                   # WebSocket relay
│       │   ├── src/index.js
│       │   ├── Dockerfile
│       │   └── package.json
│       ├── ota-server/                 # Firmware hosting
│       │   ├── src/index.js
│       │   ├── public/fw/             # Firmware files
│       │   ├── Dockerfile
│       │   └── package.json
│       └── minio/
│           ├── init.sh                # Bucket creation script
│           └── bootstrap/             # Bootstrap data
│
├── mobile/
│   └── ios-field-utility/              # iOS app
│       ├── SkyFeederFieldUtility/     # Main app target
│       │   ├── Models/                # Data models
│       │   ├── Providers/             # Data providers
│       │   └── Info.plist
│       ├── SkyFeederUI/               # UI package
│       │   └── Sources/SkyFeederUI/
│       │       ├── Models/
│       │       ├── ViewModels/
│       │       ├── Views/
│       │       ├── Providers/
│       │       ├── Support/
│       │       ├── Theme/
│       │       └── Utilities/
│       └── SkyFeederFieldUtility.xcodeproj/
│
├── skyfeeder/                          # ESP32 firmware
│   ├── skyfeeder.ino                  # Main sketch
│   ├── config.h                       # Configuration
│   ├── upload_manager.cpp             # Retry queue
│   ├── websocket_client.cpp           # WebSocket
│   └── command_handler.cpp            # Command processing
│
├── amb-mini/                           # AMB82-Mini firmware
│   └── amb-mini.ino                   # Camera sketch
│
├── tools/                              # Development tools
│   ├── ws-upload-status.js            # WebSocket testing
│   ├── ws-resilience-test.js          # Reconnect testing
│   └── cam-*.ps1                      # Camera control scripts
│
├── REPORTS/                            # Validation artifacts
│   ├── A0.4/                          # OTA validation
│   ├── A1.1/                          # Local stack validation
│   ├── A1.2/                          # Discovery + WS resilience
│   ├── A1.3/                          # Upload status + gallery
│   └── A1.4/                          # Fault injection
│
├── docs/                               # Documentation
│   ├── VALIDATION_A1.*.md             # Validation guides
│   └── PROVISIONING.md                # Provisioning docs
│
├── README_PLAYBOOK.md                  # Execution playbook
├── ARCHITECTURE.md                     # This file
└── PROPOSAL_DEHARDCODING.md           # Post-A2 config tasks
```

### Key File Responsibilities

| File | Purpose | DO NOT MODIFY |
|------|---------|---------------|
| `ops/local/presign-api/src/index.js` | Gallery endpoints, photo proxy | Photo proxy logic |
| `ops/local/docker-compose.yml` | Service configuration | Port mappings, GALLERY_PREFIX |
| `mobile/.../PresignedCaptureProvider.swift` | iOS gallery data loading | Date decoding strategy |
| `mobile/.../Capture.swift` | iOS data models | Codable structure |
| `skyfeeder/upload_manager.cpp` | ESP32 retry queue | Retry schedule |
| `README_PLAYBOOK.md` | Phase tracking | Phase completion criteria |

---

## Key Patterns

### Pattern 1: Gallery Manifest Transformation

**Location:** `ops/local/presign-api/src/index.js` (serveLatestGalleryIndex function)

**Purpose:** Transform internal day index format to iOS-compatible gallery manifest

**Implementation:**
```javascript
async function serveLatestGalleryIndex(req, res, logPrefix) {
  const { deviceId } = req.params;

  // 1. List all day index files
  const listCommand = new ListObjectsV2Command({
    Bucket: galleryBucket,
    Prefix: `${deviceId}/indices/`,
  });
  const listResult = await galleryS3.send(listCommand);

  // 2. Find newest day index
  const dayIndices = (listResult.Contents || [])
    .filter(obj => obj.Key.match(/day-\d{4}-\d{2}-\d{2}\.json$/))
    .sort((a, b) => b.Key.localeCompare(a.Key));

  if (dayIndices.length === 0) {
    return res.status(404).json({ error: "not_found" });
  }

  // 3. Fetch day index content
  const getCommand = new GetObjectCommand({
    Bucket: galleryBucket,
    Key: dayIndices[0].Key,
  });
  const getResult = await galleryS3.send(getCommand);
  const dayIndex = JSON.parse(await streamToString(getResult.Body));

  // 4. Transform to gallery manifest format
  const captures = (dayIndex.events || []).map((event) => {
    const photoUrl = `${PUBLIC_BASE}/gallery/${deviceId}/photo/${event.key}`;
    const timestampMatch = event.key.match(/^(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2})-\d{3}Z/);
    const capturedAt = timestampMatch
      ? timestampMatch[1].replace(/T(\d{2})-(\d{2})-(\d{2})/, 'T$1:$2:$3') + 'Z'
      : new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');

    return {
      id: crypto.randomUUID(),
      title: event.key,
      capturedAt,
      duration: null,
      fileSizeBytes: event.bytes || 0,
      thumbnailURL: photoUrl,
      assetURL: photoUrl,
      contentType: event.kind === "clips" ? "video/mp4" : "image/jpeg",
    };
  });

  // 5. Return manifest
  res.json({ captures });
}
```

**DO NOT MODIFY:**
- Date parsing regex
- ISO8601 format (no milliseconds)
- Photo proxy URL construction
- Manifest structure

### Pattern 2: Photo Proxy Streaming

**Location:** `ops/local/presign-api/src/index.js` (photo proxy endpoint)

**Purpose:** Stream photos from MinIO to iOS app without presigned URLs

**Implementation:**
```javascript
app.get("/gallery/:deviceId/photo/:filename", async (req, res) => {
  const { deviceId, filename } = req.params;

  try {
    const photoKey = galleryPrefix
      ? `${galleryPrefix}/${deviceId}/${filename}`
      : `${deviceId}/${filename}`;

    const getCommand = new GetObjectCommand({
      Bucket: galleryBucket,
      Key: photoKey,
    });

    const response = await galleryS3.send(getCommand);

    // Set appropriate headers
    res.set('Content-Type', response.ContentType || 'image/jpeg');
    res.set('Cache-Control', 'public, max-age=86400');
    if (response.ContentLength) {
      res.set('Content-Length', response.ContentLength.toString());
    }

    // Stream the photo data
    response.Body.pipe(res);
  } catch (err) {
    console.error(`[photo-proxy] Error serving photo ${deviceId}/${filename}:`, err);
    res.status(404).json({ error: 'photo_not_found' });
  }
});
```

**DO NOT MODIFY:**
- Photo key construction (respects GALLERY_PREFIX)
- Streaming pattern (pipe response)
- Error handling

### Pattern 3: iOS Fallback Strategy

**Location:** `mobile/.../PresignedCaptureProvider.swift`

**Purpose:** Try primary endpoint, fallback to legacy endpoint on 404

**Implementation:**
```swift
func loadCaptures() async throws -> [Capture] {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "GET"

    do {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CaptureProviderError.networkFailure("Unexpected response")
        }

        if httpResponse.statusCode == 404, let fallbackURL = fallbackEndpoint {
            logger.info("Manifest not found, retrying with legacy endpoint")
            return try await loadCapturesFromURL(fallbackURL)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CaptureProviderError.networkFailure("HTTP \(httpResponse.statusCode)")
        }

        return try parseManifest(from: data)
    } catch {
        throw error
    }
}
```

**DO NOT MODIFY:**
- Fallback logic (404 triggers fallback)
- Error propagation

### Pattern 4: ESP32 Upload Retry Queue

**Location:** `skyfeeder/upload_manager.cpp`

**Purpose:** Retry failed uploads with exponential backoff

**Pseudo-implementation:**
```cpp
void UploadManager::uploadPhoto(Photo photo) {
  // Attempt 1: Immediate
  if (uploadToMinIO(photo)) {
    broadcastSuccess();
    return;
  }

  // Attempt 2: +1 minute
  scheduleRetry(photo, 60000);
}

void UploadManager::retryUpload(Photo photo) {
  if (photo.attempts >= 4) {
    broadcastFailure();
    return;
  }

  if (uploadToMinIO(photo)) {
    broadcastSuccess();
    return;
  }

  // Calculate next retry delay
  int delays[] = {0, 60000, 300000, 900000}; // 0s, 1m, 5m, 15m
  int nextDelay = delays[photo.attempts];
  scheduleRetry(photo, nextDelay);
}
```

**DO NOT MODIFY:**
- Retry schedule (1m, 5m, 15m)
- Max attempts (4)

---

## Security Model

### Current Phase (Local Development)

**Trust Model:** Local LAN only, no authentication
- MinIO: Default credentials (`minioadmin:minioadmin`)
- presign-api: No authentication required
- ws-relay: JWT validation disabled (dev mode)
- ota-server: No authentication

**Network Assumptions:**
- All services on trusted LAN (10.0.0.x)
- No external access
- No TLS/SSL

### Future Phase (Cloud Production)

**Trust Model:** Zero-trust with JWT validation
- Cloudflare Workers: Edge authentication
- R2: Signed URLs with expiration
- WebSocket: Mandatory JWT validation
- APNs: Device tokens + Apple certificates

**Network Assumptions:**
- Public internet
- TLS/SSL everywhere
- Rate limiting
- DDoS protection (Cloudflare)

**Security Hardening Tasks:** See `PROPOSAL_DEHARDCODING.md` (post-A2)

---

## Validation Checklist

Before modifying any component, verify:

- [ ] Does this change align with local-first architecture?
- [ ] Does this break the photo proxy pattern?
- [ ] Does this change date formats (must remain ISO8601 without milliseconds)?
- [ ] Does this modify gallery manifest structure (must match iOS expectations)?
- [ ] Does this change GALLERY_PREFIX (must remain empty)?
- [ ] Does this modify port mappings (9200/9201/8080/8081/9180)?
- [ ] Does this change retry schedules (1m/5m/15m)?
- [ ] Does this break WebSocket queue/replay logic?
- [ ] Does this modify day index file naming (day-YYYY-MM-DD.json)?
- [ ] Have you updated documentation (README, PLAYBOOK, ARCHITECTURE)?

**If any answer is YES, get explicit approval before proceeding.**

---

## Contact & Escalation

**Questions about architecture:** Refer to this document first
**Proposed changes:** Document in proposal (see `PROPOSAL_DEHARDCODING.md` example)
**Validation failures:** Document in `REPORTS/` with artifacts
**Emergency issues:** Document in `REPORTS/` with `CRITICAL_` prefix

**Last updated:** 2025-11-09 by Claude Code
**Next review:** Before starting B1 phase
