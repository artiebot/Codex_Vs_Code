# A1.3.5 iOS Dashboard Polish - Code Audit Report

**Date:** 2025-11-09
**Auditor:** Claude Code
**Scope:** Backend (presign-api) + iOS (Slices 1-4)
**Status:** 15 issues identified - Codex review required

---

## Executive Summary

This audit reviews all code implemented by Codex for the A1.3.5 iOS Dashboard Polish phase. The backend implementation (11 endpoints) is **functionally complete and validated**, but has several design issues that should be addressed. The iOS implementation (Slices 1-4) is **architecturally sound** but has critical missing features and potential reliability issues.

**Critical Issues:** 4
**High Priority:** 6
**Medium Priority:** 3
**Low Priority:** 2

---

## CRITICAL Issues (Must Fix Before Production)

### CRIT-1: WebSocket Reconnection Logic Missing
**File:** [EventLogWebSocketClient.swift](../../mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/Providers/EventLogWebSocketClient.swift)
**Lines:** 40-59

**Issue:**
WebSocket client has **NO reconnection logic with exponential backoff**. Per architecture requirements (ARCHITECTURE.md:505-513), the WebSocket must implement:
- Reconnect with exponential backoff: 1s, 2s, 4s, 8s, 16s (max)
- Message queue/replay on reconnect
- Max queue size: 100 messages

**Current Behavior:**
```swift
case .failure:
    Task { @MainActor in
        self.delegate?.eventLogClient(self, didChangeState: false)
    }
```

On WebSocket failure, the client only notifies the delegate but **does not attempt to reconnect**. This violates the architectural constraint.

**Impact:**
- Users lose real-time updates permanently on network hiccup
- No automatic recovery from temporary disconnections
- Violates playbook requirement: "WebSocket: reconnect backoff: 1s, 2s, 4s, 8s, 16s (max)"

**Required Fix:**
1. Add `private var reconnectAttempts = 0`
2. Add `private var reconnectTask: Task<Void, Never>?`
3. Implement exponential backoff in `listen()` failure case
4. Add message queue array with 100-entry max
5. Replay queued messages on successful reconnect

**References:**
- README_PLAYBOOK.md:379-381
- ARCHITECTURE.md:505-513

---

### CRIT-2: Missing Message Queue for WebSocket Events
**File:** [EventLogViewModel.swift](../../mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/ViewModels/EventLogViewModel.swift)
**Lines:** 1-63

**Issue:**
EventLogViewModel has no local message queue for events received while WebSocket is disconnected. Per architecture requirements, events must be queued locally and replayed on reconnect.

**Current Behavior:**
Events are only appended when WebSocket is connected. If WebSocket drops, events sent by the server during disconnection are **permanently lost**.

**Impact:**
- Event log shows gaps during network interruptions
- User validation step 8 will FAIL: "WebSocket: kill ws-relay → queue → restore → replay"

**Required Fix:**
1. Add `private var pendingEvents: [EventLogEntry] = []`
2. Queue events received during disconnect
3. Replay queue on reconnect
4. Cap queue at 100 entries to prevent memory growth

---

### CRIT-3: Live Stream Lacks Proper Error Recovery
**File:** [LiveStreamViewModel.swift](../../mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/ViewModels/LiveStreamViewModel.swift)
**Lines:** 40-50

**Issue:**
Live stream polling continues forever on 503 errors **without implementing the required cache-buster retry pattern**. Per playbook requirements (README_PLAYBOOK.md:319), the stream must:
- Auto-retry on 503 with 2s delay
- Add cache-buster query param (`?t=<timestamp>`)

**Current Behavior:**
```swift
components.queryItems = [
    URLQueryItem(name: "cacheBust", value: UUID().uuidString)
]
```

The cache-buster is a **UUID**, not a timestamp. This is incorrect per the requirement. Also, there's no exponential backoff on repeated failures - just a fixed 2-second sleep.

**Impact:**
- Camera stream may get stuck on cached 503 responses
- No backoff means excessive polling during extended outages
- User validation step 5 may FAIL: "Live view: error → auto retry with cache buster"

**Required Fix:**
1. Change cache-buster to timestamp: `URLQueryItem(name: "t", value: "\(Int(Date().timeIntervalSince1970))")`
2. Add exponential backoff: 2s, 4s, 8s, 16s (max) on consecutive failures
3. Reset backoff counter on successful frame fetch

---

### CRIT-4: No Offline Detection for Dashboard
**File:** [DashboardViewModel.swift](../../mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/ViewModels/DashboardViewModel.swift)
**Lines:** 52-77

**Issue:**
Dashboard sets `isOffline = true` on **any error**, including legitimate HTTP errors (404, 500). This is incorrect - offline should only be set when the **network is unreachable**, not when the API returns an error.

**Current Behavior:**
```swift
} catch {
    // ...
    isOffline = true  // ❌ Wrong - sets offline on ANY error
}
```

**Impact:**
- Offline banner appears on API bugs (500 errors) when network is actually fine
- Confusing UX: "You're offline" when user has full WiFi signal
- User validation step 6 will produce false positives

**Required Fix:**
1. Only set `isOffline = true` for `URLError.notConnectedToInternet` or similar network errors
2. For HTTP errors (400, 500), show `errorMessage` but keep `isOffline = false`
3. Consider using `NWPathMonitor` for proper network connectivity detection

---

## HIGH Priority Issues

### HIGH-1: MediaProvider Doesn't Match Backend Response Schema
**Files:**
- [MediaProvider.swift](../../mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/Providers/MediaProvider.swift):76-77
- [presign-api/src/index.js](../../ops/local/presign-api/src/index.js):1443-1449

**Issue:**
MediaProvider decodes response with key `"photos"` or `"videos"`, but this assumes backend returns `{ "photos": [...] }`. However, the backend returns `{ "deviceId", "total", "count", "photos": [...] }`.

**Current Code:**
```swift
let payload = try decoder.decode([String: [MediaItem]].self, from: data)
return payload[key] ?? []
```

This decode will **fail** because the top-level object has `"deviceId"` and `"total"` fields, which don't match `[String: [MediaItem]]`.

**Impact:**
- Media carousels will show empty state even when photos exist
- User validation step 3 will FAIL: "Dashboard card parity (all cards render and load data)"

**Required Fix:**
```swift
struct MediaResponse: Decodable {
    let deviceId: String
    let total: Int
    let count: Int
    let photos: [MediaItem]?
    let videos: [MediaItem]?
}

let payload = try decoder.decode(MediaResponse.self, from: data)
return key == "photos" ? (payload.photos ?? []) : (payload.videos ?? [])
```

---

### HIGH-2: HealthProvider Doesn't Handle Nested Metrics Structure
**Files:**
- [HealthProvider.swift](../../mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/Providers/HealthProvider.swift):85-104
- [presign-api/src/index.js](../../ops/local/presign-api/src/index.js):1252-1266

**Issue:**
HealthProvider expects `weightMetrics` and `visitMetrics` at the top level, but backend returns them nested under `"metrics": { "weight": {...}, "visits": {...} }`.

**Backend Response:**
```json
{
  "deviceId": "dev1",
  "timestamp": "2025-11-09T...",
  "services": {...},
  "storage": {...},
  "metrics": {
    "weight": { "currentGrams": null, "visitsToday": 0, ... },
    "visits": { "today": 0, "totalEvents": 0, ... }
  }
}
```

**Current Decode:**
```swift
struct Payload: Decodable {
    let deviceId: String
    let timestamp: Date
    let services: [String: HealthSnapshot.ServiceStatus]
    let metrics: Metrics  // ✅ Correct

    struct Metrics: Decodable {
        let weight: HealthSnapshot.WeightMetrics
        let visits: HealthSnapshot.VisitMetrics
    }
}
```

Actually, this looks correct! But the final mapping is wrong:

```swift
return HealthSnapshot(
    deviceId: payload.deviceId,
    timestamp: payload.timestamp,
    services: payload.services,
    weightMetrics: payload.metrics.weight,  // ✅ Correct
    visitMetrics: payload.metrics.visits     // ✅ Correct
)
```

**Wait - this is actually correct!** Let me re-verify...

After review, this appears correct. **Downgrade to MEDIUM - needs validation testing only.**

---

### HIGH-3: Missing Video Proxy Endpoint in Backend
**File:** [presign-api/src/index.js](../../ops/local/presign-api/src/index.js)

**Issue:**
Backend implements `/gallery/:deviceId/photo/:filename` for photo proxy, but there's **NO equivalent `/gallery/:deviceId/video/:filename` endpoint** for videos.

**Evidence:**
```javascript
// Line 1401-1414: buildPhotoRecord exists
const buildPhotoRecord = (item, deviceId) => {
  const url = `${normalizedPublicBase}/gallery/${deviceId}/photo/${encodeURIComponent(filename)}`;
  // ...
};

// Line 1416-1429: buildVideoRecord references /video/ endpoint
const buildVideoRecord = (item, deviceId) => {
  const url = `${normalizedPublicBase}/gallery/${deviceId}/video/${encodeURIComponent(filename)}`;
  // ...
};
```

But searching the entire file, there's no route handler for `/gallery/:deviceId/video/:filename`.

**Impact:**
- Video carousel will return 404 for all video thumbnails/assets
- User validation will fail when testing video functionality

**Required Fix:**
Add video proxy endpoint:
```javascript
app.get("/gallery/:deviceId/video/:filename", async (req, res) => {
  const { deviceId, filename } = req.params;
  // Same logic as photo proxy, but use clips bucket
  // ...
});
```

---

### HIGH-4: Settings Persistence Only Server-Side (No UserDefaults)
**File:** [DashboardActionProvider.swift](../../mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/Providers/DashboardActionProvider.swift)

**Issue:**
Dashboard action provider calls `/api/settings` POST endpoint, but there's **no iOS-side persistence to UserDefaults**. Per playbook requirements (README_PLAYBOOK.md:361-363):
- Settings must persist to UserDefaults
- Settings must apply without relaunch

**Current Implementation:**
DashboardActionProvider only sends settings to server. There's no code to save settings locally or reload app configuration.

**Impact:**
- User validation step 12 will FAIL: "Settings persistence (UserDefaults + server sync)"
- Settings don't persist across app restarts

**Required Fix:**
1. Create `SettingsProvider` with UserDefaults persistence
2. Save settings locally after successful POST
3. Apply settings changes to active providers without relaunch

---

### HIGH-5: DashboardViewModel Auto-Refresh Task Memory Leak Risk
**File:** [DashboardViewModel.swift](../../mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/ViewModels/DashboardViewModel.swift):42-50

**Issue:**
`startAutoRefresh()` recursively spawns new tasks every 30 seconds **without checking if previous task is still running**. This creates a memory leak risk if called multiple times.

**Current Code:**
```swift
public func startAutoRefresh() {
    refreshTask?.cancel()  // ✅ Good - cancels previous
    refreshTask = Task { [weak self] in
        await self?.refresh()
        try? await Task.sleep(for: .seconds(30))
        if Task.isCancelled { return }
        await self?.startAutoRefresh()  // ⚠️ Recursive call creates new task
    }
}
```

**Problem:**
If `startAutoRefresh()` is called externally multiple times (e.g., user pulls to refresh while auto-refresh is running), the recursive call inside the task creates a **second refresh loop**.

**Impact:**
- Memory leak: Multiple refresh tasks running simultaneously
- Excessive API calls: 2x or 3x normal request rate

**Required Fix:**
Use a flag to prevent concurrent refresh loops:
```swift
private var isAutoRefreshing = false

public func startAutoRefresh() {
    guard !isAutoRefreshing else { return }
    isAutoRefreshing = true
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
        while !Task.isCancelled {
            await self?.refresh()
            try? await Task.sleep(for: .seconds(30))
        }
        await MainActor.run { self?.isAutoRefreshing = false }
    }
}
```

---

### HIGH-6: Backend WebSocket Emission Has No Error Handling
**File:** [presign-api/src/index.js](../../ops/local/presign-api/src/index.js):725-752

**Issue:**
`emitWsEvent()` function creates a WebSocket connection but has **minimal error handling**. If ws-relay is down, the function silently fails and returns `{ sent: false }`, but the calling endpoints don't check this status.

**Current Code:**
```javascript
const emitWsEvent = async (deviceId, payload) => {
  return await new Promise((resolve) => {
    const finish = (sent, errorMessage) => {
      resolve({ sent, errorMessage: errorMessage || null });
    };
    const relayUrl = new URL(wsRelayWsBase.toString());
    relayUrl.searchParams.set("deviceId", deviceId);
    const ws = new WebSocket(relayUrl.toString(), { handshakeTimeout: 3000 });
    ws.on("open", () => { ws.send(JSON.stringify(payload)); ws.close(); });
    ws.on("close", () => finish(true));
    ws.on("error", (err) => finish(false, err?.message));
  });
};
```

**Problem:**
Endpoints like `/api/trigger/manual` call `emitActionEvent()` which calls `emitWsEvent()`, but they **don't check if the event was actually sent**. They return `success: true` even if WebSocket broadcast failed.

**Impact:**
- User sees "Manual trigger sent" toast even when WebSocket is down
- Device never receives the trigger event
- Misleading UX

**Required Fix:**
Check `websocket.sent` status and throw error if false:
```javascript
app.post("/api/trigger/manual", async (req, res) => {
  // ...
  const websocket = await emitActionEvent(deviceId, "manual_trigger", "...");
  if (!websocket.sent) {
    return res.status(503).json({
      error: "websocket_unavailable",
      message: "WebSocket relay is offline"
    });
  }
  res.json({ success: true, deviceId, message: "Manual trigger sent", websocket });
});
```

---

## MEDIUM Priority Issues

### MED-1: Health Endpoint Swallows All Errors
**File:** [presign-api/src/index.js](../../ops/local/presign-api/src/index.js):1188-1286

**Issue:**
The `/api/health` endpoint wraps everything in a try/catch and returns `500 { error: "health_unavailable" }` for **any error**, including programming bugs. This makes debugging difficult.

**Current Code:**
```javascript
app.get("/api/health", async (req, res) => {
  try {
    // ... 100 lines of logic ...
  } catch (err) {
    console.error("[api:health] unexpected failure", err);
    res.status(500).json({ error: "health_unavailable" });
  }
});
```

**Impact:**
- TypeErrors, undefined reference errors, etc. are masked as "health_unavailable"
- No stack traces in response (only in server logs)
- Harder to debug issues during development

**Recommendation:**
In development mode, return stack trace in error response:
```javascript
} catch (err) {
    console.error("[api:health] unexpected failure", err);
    const response = { error: "health_unavailable" };
    if (process.env.NODE_ENV === "development") {
        response.debug = { message: err.message, stack: err.stack };
    }
    res.status(500).json(response);
}
```

---

### MED-2: No Timeout on Dashboard Health Checks
**File:** [presign-api/src/index.js](../../ops/local/presign-api/src/index.js):782-803

**Issue:**
`checkMinioHealth()` and `checkWsRelayHealth()` use `fetch()` with **no timeout**. If MinIO hangs, the health check hangs forever, blocking the entire `/api/health` response.

**Current Code:**
```javascript
const checkMinioHealth = async () => {
  const started = Date.now();
  try {
    const response = await fetch(minioHealthUrl);  // ⚠️ No timeout
    // ...
  }
};
```

**Impact:**
- Health endpoint can hang for 60+ seconds if MinIO is unresponsive
- Poor UX: Dashboard appears frozen

**Required Fix:**
Add timeout:
```javascript
const controller = new AbortController();
const timeoutId = setTimeout(() => controller.abort(), 5000);
try {
  const response = await fetch(minioHealthUrl, { signal: controller.signal });
  clearTimeout(timeoutId);
  // ...
} catch (err) {
  clearTimeout(timeoutId);
  if (err.name === 'AbortError') {
    return { status: "timeout", latencyMs: 5000 };
  }
  // ...
}
```

---

### MED-3: DashboardViewModel Dismisses Banner After Fixed 3s
**File:** [DashboardViewModel.swift](../../mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/ViewModels/DashboardViewModel.swift):111-119

**Issue:**
Toast banner auto-dismisses after exactly 3 seconds, regardless of message length. Long error messages may not be readable in 3 seconds.

**Current Code:**
```swift
private func dismissBannerAfterDelay() {
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(3))  // ⚠️ Fixed 3s
        // ...
    }
}
```

**Impact:**
- Users may not have time to read long error messages
- Poor accessibility for users with reading disabilities

**Recommendation:**
Calculate duration based on message length (min 3s, max 7s):
```swift
let duration = min(max(3.0, Double(message.count) / 15.0), 7.0)
try? await Task.sleep(for: .seconds(duration))
```

---

## LOW Priority Issues

### LOW-1: Inconsistent Error Types Between Providers
**Files:** Multiple provider files

**Issue:**
Each provider defines its own error enum (MediaProviderError, HealthProviderError, DashboardActionError) with duplicate cases like `missingAPIBase`, `invalidResponse`, `httpStatus(Int)`.

**Impact:**
- Code duplication (3 nearly identical error enums)
- Harder to maintain: changing error messages requires updating 3 files

**Recommendation:**
Create shared `APIError` enum:
```swift
public enum APIError: LocalizedError {
    case missingAPIBase
    case invalidResponse
    case httpStatus(Int, endpoint: String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIBase:
            return "Missing API base URL in Settings."
        case .invalidResponse:
            return "Unexpected API response format."
        case .httpStatus(let code, let endpoint):
            return "\(endpoint) failed (HTTP \(code))."
        }
    }
}
```

---

### LOW-2: Event Log Reverses Array on Every Render
**File:** [EventLogView.swift](../../mobile/ios-field-utility/SkyFeederUI/Sources/SkyFeederUI/Views/Dashboard/EventLogView.swift):16

**Issue:**
Event log reverses the events array **on every SwiftUI render** to show newest-first.

**Current Code:**
```swift
ForEach(viewModel.events.reversed()) { event in
```

**Impact:**
- O(n) array copy on every render
- If events array has 50 items and view renders 60 FPS, that's 3000 array copies/second
- Negligible performance impact with 50 items, but inefficient

**Recommendation:**
Reverse once in ViewModel:
```swift
// EventLogViewModel
@Published public private(set) var eventsReversed: [EventLogEntry] = []

private func append(_ entry: EventLogEntry) {
    events.append(entry)
    eventsReversed = events.reversed()  // Reverse once
    // ...
}
```

---

## Architectural Compliance Review

### ✅ COMPLIANT:
- Photo proxy pattern used (no presigned URLs in iOS)
- ISO8601 date format in backend (no milliseconds)
- Gallery manifest format matches iOS expectations
- GALLERY_PREFIX empty as required
- Settings validation (weightThreshold 1-500g, cooldownSeconds 60-3600s)

### ❌ NON-COMPLIANT:
- **WebSocket reconnection logic missing** (CRIT-1) - violates ARCHITECTURE.md:505-513
- **Message queue/replay missing** (CRIT-2) - violates README_PLAYBOOK.md:379-381
- **Video proxy endpoint missing** (HIGH-3) - inconsistent with photo proxy pattern
- **Settings not persisted to UserDefaults** (HIGH-4) - violates README_PLAYBOOK.md:361-363

---

## Testing Recommendations

### Unit Tests Needed:
1. `normalizeSettingsUpdate()` - test all validation edge cases
2. `buildPhotoRecord()` / `buildVideoRecord()` - test timestamp extraction
3. `deriveVisitMetrics()` - test day index parsing
4. WebSocket reconnection logic (after implementing CRIT-1)
5. Message queue replay (after implementing CRIT-2)

### Integration Tests Needed:
1. Health endpoint with MinIO down (should return degraded status, not crash)
2. WebSocket broadcast failure handling
3. Settings persistence across app restarts
4. Carousel lazy loading with 200+ photos

### Load Tests Needed:
1. `/api/health` with 10 concurrent requests (check for race conditions)
2. Event log with 1000 rapid WebSocket events (check memory growth)
3. Day index update with 5 concurrent uploads (check for 412 Precondition Failed handling)

---

## Summary of Required Fixes

**Before User Validation:**
- [ ] Fix CRIT-1: Implement WebSocket reconnection with exponential backoff
- [ ] Fix CRIT-2: Add message queue for WebSocket events
- [ ] Fix CRIT-3: Fix live stream cache-buster (use timestamp, not UUID)
- [ ] Fix CRIT-4: Implement proper offline detection (network errors only)
- [ ] Fix HIGH-1: Fix MediaProvider response schema mismatch
- [ ] Fix HIGH-3: Add video proxy endpoint
- [ ] Fix HIGH-4: Implement Settings persistence to UserDefaults

**Nice to Have:**
- [ ] Fix HIGH-5: Prevent concurrent auto-refresh loops
- [ ] Fix HIGH-6: Check WebSocket send status in action endpoints
- [ ] Fix MED-1: Return stack traces in development mode
- [ ] Fix MED-2: Add timeouts to health checks
- [ ] Fix MED-3: Variable toast duration based on message length

**Optional Refactoring:**
- [ ] Fix LOW-1: Consolidate error types into shared APIError
- [ ] Fix LOW-2: Reverse event log array once in ViewModel

---

**Next Steps:**
1. Codex reviews this report and prioritizes fixes
2. Critical issues (CRIT-1 through CRIT-4) must be fixed before user validation
3. High-priority issues (HIGH-1 through HIGH-6) should be fixed before TestFlight
4. Medium/Low issues can be deferred to post-A1.3.5 cleanup

**Validation Status:** ⏸️ BLOCKED until CRIT-1, CRIT-2, HIGH-1, and HIGH-3 are fixed.
