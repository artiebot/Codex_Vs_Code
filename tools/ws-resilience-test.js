#!/usr/bin/env node
/**
 * Simulate device/app WebSocket behaviour to validate reconnect + latency.
 */

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const DEVICE_ID = process.env.SF_DEVICE_ID || "dev1";
const WS_URL = process.env.SF_WS_URL || "ws://localhost:8081";
const JWT_SECRET = process.env.SF_JWT_SECRET || "dev-only";
const TOTAL_EVENTS = Number(process.env.SF_EVENT_COUNT || 8);
const OFFLINE_AFTER = Number(process.env.SF_DROP_AFTER || 3); // events before simulated drop
const OFFLINE_DURATION_MS = Number(process.env.SF_DROP_DURATION_MS || 4000);
const EVENT_INTERVAL_MS = Number(process.env.SF_EVENT_INTERVAL_MS || 1000);

const reportDir = path.resolve("REPORTS", "A1.2");
const logPath = path.join(reportDir, "ws_reconnect.log");
const latencyPath = path.join(reportDir, "latency_hist.json");
const notificationsPath = path.join(reportDir, "notifications.md");

if (!fs.existsSync(reportDir)) {
  fs.mkdirSync(reportDir, { recursive: true });
}

const logLines = [];
const latencyEvents = [];
let offlineRecords = [];

function log(message) {
  const line = `${new Date().toISOString()} ${message}`;
  console.log(line);
  logLines.push(line);
}

function base64url(data) {
  return Buffer.from(data)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function signJwt(payload) {
  const header = { alg: "HS256", typ: "JWT" };
  const iat = Math.floor(Date.now() / 1000);
  const body = { iat, exp: iat + 3600, ...payload };
  const encodedHeader = base64url(JSON.stringify(header));
  const encodedPayload = base64url(JSON.stringify(body));
  const signature = crypto
    .createHmac("sha256", JWT_SECRET)
    .update(`${encodedHeader}.${encodedPayload}`)
    .digest("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

const deviceToken = signJwt({ deviceId: DEVICE_ID, role: "device" });
const appToken = signJwt({ deviceId: DEVICE_ID, role: "app" });

const pendingEvents = new Map();
const queue = [];
let queuedCounter = 0;
let eventSeq = 0;
let deviceSocket = null;
let appSocket = null;
let deviceReady = false;
let reconnectAttempts = 0;
let dropTimer = null;
let eventTimer = null;
let reconnectTimer = null;
let finished = false;
let offlineStart = null;

function writeReports(summary) {
  fs.writeFileSync(logPath, `${logLines.join("\n")}\n`, "utf8");
  fs.writeFileSync(
    latencyPath,
    JSON.stringify(
      {
        deviceId: DEVICE_ID,
        eventCount: latencyEvents.length,
        reconnectAttempts,
        offlineWindows: offlineRecords,
        events: latencyEvents,
        summary,
      },
      null,
      2
    ),
    "utf8"
  );
  const md = [
    "# WebSocket Resilience Validation (A1.2)",
    "",
    `- Device ID: \`${DEVICE_ID}\``,
    `- Total events generated: **${summary.totalEvents}**`,
    `- Events sent while offline (queued): **${summary.queuedEvents}**`,
    `- Reconnect attempts: **${reconnectAttempts}**`,
    `- Offline windows: ${offlineRecords
      .map((r) => `${(r.durationMs / 1000).toFixed(1)}s`)
      .join(", ") || "none"}`,
    "",
    "## Latency Statistics",
    "",
    `- Min: ${summary.latency.min.toFixed(1)} ms`,
    `- P50: ${summary.latency.p50.toFixed(1)} ms`,
    `- P95: ${summary.latency.p95.toFixed(1)} ms`,
    `- Max: ${summary.latency.max.toFixed(1)} ms`,
  ].join("\n");
  fs.writeFileSync(notificationsPath, `${md}\n`, "utf8");
}

function percentile(values, p) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1);
  return sorted[idx];
}

function computeSummary() {
  const latencies = latencyEvents.map((entry) => entry.latencyMs);
  return {
    totalEvents: eventSeq,
    queuedEvents: queuedCounter,
    latency: {
      min: latencies.length ? Math.min(...latencies) : 0,
      max: latencies.length ? Math.max(...latencies) : 0,
      p50: percentile(latencies, 50),
      p95: percentile(latencies, 95),
    },
  };
}

function cleanup() {
  if (finished) return;
  finished = true;
  if (eventTimer) clearInterval(eventTimer);
  if (dropTimer) clearTimeout(dropTimer);
  if (reconnectTimer) clearTimeout(reconnectTimer);
  if (deviceSocket && deviceSocket.readyState === deviceSocket.OPEN) {
    deviceSocket.close(1000, "test complete");
  }
  if (appSocket && appSocket.readyState === appSocket.OPEN) {
    appSocket.close(1000, "test complete");
  }
  const summary = computeSummary();
  writeReports(summary);
  log("Test complete – reports written.");
  setTimeout(() => process.exit(0), 200);
}

function scheduleReconnect() {
  reconnectAttempts += 1;
  reconnectTimer = setTimeout(() => {
    log("Attempting device reconnect...");
    connectDevice();
  }, Math.max(1000, OFFLINE_DURATION_MS));
}

function flushQueue() {
  if (!queue.length) return;
  log(`Flushing ${queue.length} queued events after reconnect.`);
  while (queue.length) {
    const event = queue.shift();
    event.attempt += 1;
    sendEvent(event, true);
  }
}

function sendEvent(event, isReplay = false) {
  const payload = {
    eventId: event.id,
    sentTs: event.sentTs,
    attempt: event.attempt,
    replay: isReplay,
  };
  const message = {
    type: "event.notification",
    payload,
  };
  pendingEvents.set(event.id, { ...event, lastSendTs: Date.now() });
  if (deviceSocket && deviceReady && deviceSocket.readyState === deviceSocket.OPEN) {
    deviceSocket.send(JSON.stringify(message));
    log(`Sent event ${event.id} (attempt ${event.attempt}${isReplay ? ", replay" : ""})`);
  } else {
    queue.push(event);
    queuedCounter += 1;
    log(`Device offline, queued event ${event.id}`);
  }
}

function generateEvent() {
  eventSeq += 1;
  const id = `evt-${Date.now()}-${eventSeq}`;
  const event = {
    id,
    sentTs: Date.now(),
    attempt: 1,
  };
  sendEvent(event);
  if (eventSeq === OFFLINE_AFTER) {
    dropTimer = setTimeout(() => {
      if (deviceSocket) {
        log("Simulating transport drop for device connection...");
        offlineStart = Date.now();
        deviceSocket.close(4000, "simulated-drop");
      }
    }, 250);
  }
  if (eventSeq >= TOTAL_EVENTS) {
    clearInterval(eventTimer);
  }
}

function maybeFinish() {
  if (latencyEvents.length >= TOTAL_EVENTS && pendingEvents.size === 0 && queue.length === 0) {
    setTimeout(cleanup, 1000);
  }
}

function handleAppMessage(data) {
  let payload;
  try {
    payload = JSON.parse(data);
  } catch (err) {
    log(`App client received non-JSON message: ${data}`);
    return;
  }
  if (payload.type === "system") {
    log("App received system message after connect.");
    return;
  }
  const { type } = payload;
  if (type !== "event.notification") {
    log(`App received ${type}; ignoring.`);
    return;
  }
  const info = payload.payload || {};
  const record = pendingEvents.get(info.eventId);
  const recvTs = Date.now();
  const latencyMs = info.sentTs ? recvTs - info.sentTs : null;
  latencyEvents.push({
    eventId: info.eventId,
    sentTs: info.sentTs,
    recvTs,
    latencyMs,
    attempt: info.attempt,
    replay: !!info.replay,
  });
  pendingEvents.delete(info.eventId);
  log(
    `App received ${info.eventId} (latency ${latencyMs != null ? latencyMs.toFixed(1) : "n/a"} ms, attempt ${
      info.attempt
    })`
  );
  maybeFinish();
}

function connectApp() {
  const ws = new WebSocket(`${WS_URL}?token=${appToken}`);
  ws.onopen = () => log("App socket connected.");
  ws.onclose = (evt) => {
    log(`App socket closed (code=${evt.code} reason=${evt.reason || ""})`);
    if (!finished) {
      setTimeout(connectApp, 500);
    }
  };
  ws.onerror = (err) => {
    log(`App socket error: ${err.message || err}`);
  };
  ws.onmessage = (evt) => handleAppMessage(evt.data);
  appSocket = ws;
}

function connectDevice() {
  if (deviceSocket && deviceSocket.readyState === deviceSocket.OPEN) {
    deviceSocket.close(1000, "reconnect");
  }
  const ws = new WebSocket(`${WS_URL}?token=${deviceToken}`);
  ws.onopen = () => {
    deviceReady = true;
    log("Device socket connected.");
    if (offlineStart) {
      const durationMs = Date.now() - offlineStart;
      offlineRecords.push({ startTs: offlineStart, endTs: Date.now(), durationMs });
      log(`Offline window duration ${durationMs} ms`);
      offlineStart = null;
    }
    flushQueue();
  };
  ws.onclose = (evt) => {
    deviceReady = false;
    log(`Device socket closed (code=${evt.code} reason=${evt.reason || ""})`);
    if (!finished) {
      if (!offlineStart) {
        offlineStart = Date.now();
      }
      scheduleReconnect();
    }
  };
  ws.onerror = (err) => {
    log(`Device socket error: ${err.message || err}`);
  };
  deviceSocket = ws;
}

function start() {
  log("Starting WebSocket resilience test...");
  connectApp();
  connectDevice();
  eventTimer = setInterval(generateEvent, EVENT_INTERVAL_MS);
  // Ensure termination if something hangs beyond test duration.
  setTimeout(() => {
    if (!finished) {
      log("Timeout reached – forcing cleanup.");
      cleanup();
    }
  }, 5 * 60 * 1000);
}

start();
