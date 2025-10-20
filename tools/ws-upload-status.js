#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const http = require("http");
const https = require("https");

const DEVICE_ID = process.env.SF_DEVICE_ID || "dev1";
const WS_URL = process.env.SF_WS_URL || "ws://localhost:8081";
const JWT_SECRET = process.env.SF_JWT_SECRET || "dev-only";
const OFFLINE_DURATION_MS = Number(process.env.SF_DROP_DURATION_MS || 4000);
const SEND_DELAY_MS = Number(process.env.SF_STATUS_DELAY_MS || 350);
const OBJECT_KEY =
  process.env.SF_UPLOAD_OBJECT_KEY || `${DEVICE_ID}/uploads/demo-${Date.now()}.jpg`;

const STATUS_SEQUENCE = [
  { sequence: 1, status: "queued", attempt: 1 },
  { sequence: 2, status: "uploading", attempt: 1, progress_pct: 32 },
  { sequence: 3, status: "uploading", attempt: 1, progress_pct: 68, offlineTrigger: true },
  { sequence: 4, status: "retry_scheduled", attempt: 1, next_retry_sec: 60, replay: true },
  { sequence: 5, status: "uploading", attempt: 2, progress_pct: 46, replay: true },
  { sequence: 6, status: "uploading", attempt: 2, progress_pct: 89, replay: true },
  { sequence: 7, status: "success", attempt: 2, latency_ms: 1850, replay: true },
  { sequence: 8, status: "gallery_ack", attempt: 2 },
];

const reportDir = path.resolve("REPORTS", "A1.3");
const logPath = path.join(reportDir, "ws_reconnect.log");
const capturePath = path.join(reportDir, "ws_capture.json");
const metricsPath = path.join(reportDir, "metrics_before_after.json");
const notesPath = path.join(reportDir, "notifications.md");
fs.mkdirSync(reportDir, { recursive: true });

const wsUrlObj = new URL(WS_URL);
const metricsUrl =
  process.env.SF_WS_METRICS ||
  `${wsUrlObj.protocol === "wss:" ? "https:" : "http:"}//${wsUrlObj.host}/v1/metrics`;

const logLines = [];
const statusEvents = [];
const offlineWindows = [];
let reconnectAttempts = 0;
let metricsBefore = null;
let metricsAfter = null;

function log(message) {
  const line = `${new Date().toISOString()} ${message}`;
  console.log(line);
  logLines.push(line);
}

function base64url(input) {
  return Buffer.from(input)
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
  const encodedBody = base64url(JSON.stringify(body));
  const signature = crypto
    .createHmac("sha256", JWT_SECRET)
    .update(`${encodedHeader}.${encodedBody}`)
    .digest("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
  return `${encodedHeader}.${encodedBody}.${signature}`;
}

function fetchMetrics() {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(metricsUrl);
    const lib = urlObj.protocol === "https:" ? https : http;
    const req = lib.get(urlObj, (res) => {
      if (res.statusCode !== 200) {
        res.resume();
        reject(new Error(`metrics status ${res.statusCode}`));
        return;
      }
      let data = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        data += chunk;
      });
      res.on("end", () => {
        try {
          resolve(JSON.parse(data || "{}"));
        } catch (err) {
          reject(err);
        }
      });
    });
    req.on("error", reject);
  });
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function openSocket(token, label, messageHandler) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`${WS_URL}?token=${token}`);
    const timer = setTimeout(() => {
      reject(new Error(`${label} socket open timeout`));
      try {
        ws.close();
      } catch (_) {}
    }, 5000);

    ws.onopen = () => {
      clearTimeout(timer);
      log(`${label} socket connected.`);
      resolve(ws);
    };

    ws.onerror = (err) => {
      clearTimeout(timer);
      reject(err);
    };

    ws.onmessage = (evt) => {
      if (messageHandler) {
        messageHandler(evt.data);
      }
    };
  });
}

function writeReports(summary) {
  fs.writeFileSync(logPath, `${logLines.join("\n")}\n`, "utf8");
  const capture = {
    deviceId: DEVICE_ID,
    objectKey: OBJECT_KEY,
    reconnectAttempts,
    offlineWindows,
    events: statusEvents,
    summary,
  };
  fs.writeFileSync(capturePath, JSON.stringify(capture, null, 2), "utf8");
  fs.writeFileSync(
    metricsPath,
    JSON.stringify({ before: metricsBefore, after: metricsAfter }, null, 2),
    "utf8"
  );
  const md = [
    "# WebSocket Upload Status Validation (A1.3)",
    "",
    `- Device ID: \`${DEVICE_ID}\`` ,
    `- Object key: \`${OBJECT_KEY}\`` ,
    `- Total stages sent: **${summary.totalStages}**` ,
    `- Stages replayed after reconnect: **${summary.replayedStages}**` ,
    `- Reconnect attempts: **${reconnectAttempts}**` ,
    `- Offline windows: ${offlineWindows
      .map((w) => `${(w.durationMs / 1000).toFixed(1)}s`)
      .join(", ") || "none"}` ,
    "",
    "## Latency Statistics",
    "",
    `- Min: ${summary.latency.min.toFixed(1)} ms` ,
    `- P50: ${summary.latency.p50.toFixed(1)} ms` ,
    `- P95: ${summary.latency.p95.toFixed(1)} ms` ,
    `- Max: ${summary.latency.max.toFixed(1)} ms` ,
  ].join("\n");
  fs.writeFileSync(notesPath, `${md}\n`, "utf8");
}

function percentile(values, p) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1);
  return sorted[idx];
}

function computeSummary() {
  const latencies = statusEvents
    .map((evt) => evt.latencyMs)
    .filter((value) => typeof value === "number" && !Number.isNaN(value));
  return {
    totalStages: statusEvents.length,
    replayedStages: statusEvents.filter((evt) => evt.replay).length,
    latency: {
      min: latencies.length ? Math.min(...latencies) : 0,
      max: latencies.length ? Math.max(...latencies) : 0,
      p50: percentile(latencies, 50),
      p95: percentile(latencies, 95),
    },
  };
}

function recordStatusEvent(payload) {
  const recvTs = Date.now();
  const latencyMs = payload.sentTs ? recvTs - payload.sentTs : null;
  statusEvents.push({
    sequence: payload.sequence,
    status: payload.status,
    attempt: payload.attempt,
    replay: !!payload.replay,
    sentTs: payload.sentTs,
    recvTs,
    latencyMs,
  });
}

async function run() {
  metricsBefore = await fetchMetrics().catch((err) => {
    log(`Failed to fetch metrics before test: ${err.message || err}`);
    return null;
  });

  const appSocket = await openSocket(signJwt({ deviceId: DEVICE_ID, role: "app" }), "App", (data) => {
    try {
      const message = JSON.parse(data);
      if (message.type !== "event.upload_status") {
        return;
      }
      recordStatusEvent(message.payload);
      log(
        `App received ${message.payload.status} (sequence ${message.payload.sequence}, attempt ${message.payload.attempt})`
      );
    } catch (err) {
      log(`App message parse error: ${err.message || err}`);
    }
  });

  let deviceSocket = await openSocket(signJwt({ deviceId: DEVICE_ID, role: "device" }), "Device");
  deviceSocket.onclose = (evt) => {
    log(`Device socket closed (code=${evt.code} reason=${evt.reason || ""})`);
  };

  const dropIndex = STATUS_SEQUENCE.findIndex((stage) => stage.offlineTrigger);
  const preDropStages = dropIndex >= 0 ? STATUS_SEQUENCE.slice(0, dropIndex + 1) : [...STATUS_SEQUENCE];
  const postDropStages = dropIndex >= 0 ? STATUS_SEQUENCE.slice(dropIndex + 1) : [];
  const eventId = `upload-${Date.now()}`;

  const sendStage = async (stage, replay = false) => {
    const payload = {
      eventId,
      object_key: OBJECT_KEY,
      sequence: stage.sequence,
      status: stage.status,
      attempt: stage.attempt,
      sentTs: Date.now(),
      replay: replay || !!stage.replay,
    };
    if (stage.progress_pct !== undefined) {
      payload.progress_pct = stage.progress_pct;
    }
    if (stage.next_retry_sec !== undefined) {
      payload.next_retry_sec = stage.next_retry_sec;
    }
    if (stage.latency_ms !== undefined) {
      payload.latency_ms = stage.latency_ms;
    }
    deviceSocket.send(JSON.stringify({ type: "event.upload_status", payload }));
    log(`Sent status ${stage.status} (sequence ${stage.sequence}, attempt ${stage.attempt})`);
    await wait(SEND_DELAY_MS);
  };

  for (const stage of preDropStages) {
    await sendStage(stage);
    if (stage.offlineTrigger) {
      log("Simulating device socket drop");
      deviceSocket.close(4000, "simulated-drop");
      const offlineStart = Date.now();
      await wait(OFFLINE_DURATION_MS);
      reconnectAttempts += 1;
      deviceSocket = await openSocket(signJwt({ deviceId: DEVICE_ID, role: "device" }), "Device");
      deviceSocket.onclose = (evt) => {
        log(`Device socket closed (code=${evt.code} reason=${evt.reason || ""})`);
      };
      const offlineEnd = Date.now();
      offlineWindows.push({ startTs: offlineStart, endTs: offlineEnd, durationMs: offlineEnd - offlineStart });
      for (const queued of postDropStages) {
        await sendStage(queued, true);
      }
      break;
    }
  }

  if (!preDropStages.length) {
    for (const stage of postDropStages) {
      await sendStage(stage, true);
    }
  }

  await wait(1000);
  deviceSocket.close(1000, "test-complete");
  appSocket.close(1000, "test-complete");

  metricsAfter = await fetchMetrics().catch((err) => {
    log(`Failed to fetch metrics after test: ${err.message || err}`);
    return null;
  });

  const summary = computeSummary();
  writeReports(summary);
  log("A1.3 upload-status test complete.");
}

run().catch((err) => {
  log(`Fatal error: ${err.message || err}`);
  process.exit(1);
});


