import dotenv from "dotenv";
dotenv.config();

import express from "express";
import bodyParser from "body-parser";
import morgan from "morgan";
import { nanoid } from "nanoid";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import path from "path";
import fs from "fs/promises";
import { execFile } from "child_process";
import { promisify } from "util";
import { Readable } from "stream";
import WebSocket from "ws";
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  HeadObjectCommand,
  DeleteObjectsCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const {
  PORT = 8080,
  S3_ENDPOINT,
  S3_REGION = "us-east-1",
  S3_BUCKET_PHOTOS = "photos",
  S3_BUCKET_CLIPS = "clips",
  S3_BUCKET_INDICES = "photos",
  S3_ACCESS_KEY,
  S3_SECRET_KEY,
  JWT_SECRET: PROVIDED_JWT_SECRET,
  PUBLIC_BASE = `http://localhost:${PORT}`,
  S3_PHOTOS_BASE = "http://localhost:9200/photos",
  S3_CLIPS_BASE = "http://localhost:9200/clips",
  WS_PUBLIC_BASE = "http://localhost:8081",
  WS_INTERNAL_BASE,
  OTA_BASE = "http://localhost:9180",
  ENV_TIER,
  INDEX_SAFE_APPEND,
  INDEX_MAX_EVENTS,
  INDEX_SAFE_RETRIES,
  MINIO_ENDPOINT,
  MINIO_ACCESS_KEY,
  MINIO_SECRET_KEY,
  DEFAULT_DEVICE_ID = "dev1",
  LOG_SNAPSHOT_PATHS = "logs,/var/log/skyfeeder",
  STORAGE_MOUNT_PATH = "/",
  CAMERA_STREAM_URL,
  LOCAL_STACK_DIR,
} = process.env;
const normalizedPublicBase = (PUBLIC_BASE || `http://localhost:${PORT}`).replace(/\/+$/, "");

const JWT_SECRET = PROVIDED_JWT_SECRET || "dev-only";
const environmentLabel = (ENV_TIER || process.env.NODE_ENV || "development").toLowerCase();
const productionLike = environmentLabel === "production" || environmentLabel === "prod";
const weakJwtSecret = JWT_SECRET === "dev-only";

if (weakJwtSecret) {
  const warningMsg =
    "JWT_SECRET is using the default 'dev-only' value; presigned tokens are forgeable.";
  if (productionLike) {
    console.error(`${warningMsg} Set JWT_SECRET before running in production.`);
    process.exit(1);
  } else {
    console.warn(warningMsg);
  }
}

if (!S3_ENDPOINT || !S3_ACCESS_KEY || !S3_SECRET_KEY) {
  console.error(
    "Missing S3 configuration. Ensure S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY are set."
  );
  process.exit(1);
}

const s3 = new S3Client({
  region: S3_REGION,
  endpoint: S3_ENDPOINT,
  forcePathStyle: true,
  credentials: {
    accessKeyId: S3_ACCESS_KEY,
    secretAccessKey: S3_SECRET_KEY,
  },
});

const galleryS3 = new S3Client({
  region: S3_REGION,
  endpoint: MINIO_ENDPOINT || S3_ENDPOINT,
  forcePathStyle: true,
  credentials: {
    accessKeyId: MINIO_ACCESS_KEY || S3_ACCESS_KEY,
    secretAccessKey: MINIO_SECRET_KEY || S3_SECRET_KEY,
  },
});

// S3 client configured with public endpoint for generating presigned URLs
const publicS3 = new S3Client({
  region: S3_REGION,
  endpoint: S3_PHOTOS_BASE.replace(/\/photos$/, ''),
  forcePathStyle: true,
  credentials: {
    accessKeyId: MINIO_ACCESS_KEY || S3_ACCESS_KEY,
    secretAccessKey: MINIO_SECRET_KEY || S3_SECRET_KEY,
  },
});

const GALLERY_BUCKET = process.env.GALLERY_BUCKET || "photos";
const GALLERY_PREFIX = process.env.GALLERY_PREFIX !== undefined ? process.env.GALLERY_PREFIX : "photos";
const galleryBucket = GALLERY_BUCKET.trim();
const galleryPrefix = GALLERY_PREFIX.replace(/^\/+|\/+$/g, "");
const galleryCache = new Map();
const CACHE_MS = 60000;
const deviceTelemetry = new Map();
const execFileAsync = promisify(execFile);
const defaultDeviceId = (DEFAULT_DEVICE_ID || "dev1").trim() || "dev1";
const logSnapshotRoots = (LOG_SNAPSHOT_PATHS || "")
  .split(",")
  .map((entry) => entry.trim())
  .filter(Boolean);
const storageMountPath = (STORAGE_MOUNT_PATH || "/").trim() || "/";
const fetchImpl = typeof fetch === "function" ? fetch : null;
const dataDir = path.resolve(process.cwd(), "data");
const deviceSettingsPath = path.join(dataDir, "device-settings.json");
const settingsDefaults = {
  weightThreshold: 50,
  cooldownSeconds: 300,
  cameraEnabled: true,
};
let cachedSettingsStore = null;
const wsInternalBase = (WS_INTERNAL_BASE || WS_PUBLIC_BASE || "http://ws-relay:8081" || "").trim();
let wsRelayWsBase = null;
if (wsInternalBase) {
  try {
    const relayUrl = new URL(wsInternalBase);
    relayUrl.protocol = relayUrl.protocol.replace(/^http/i, "ws");
    wsRelayWsBase = relayUrl;
  } catch (err) {
    console.warn("[ws-relay] invalid WS base", wsInternalBase, err?.message || err);
  }
}
const cameraStreamUrl = (CAMERA_STREAM_URL || "").trim();
const localStackDir = path.resolve(LOCAL_STACK_DIR || path.join(process.cwd(), ".."));
const MAX_LOG_BUFFER_LINES = 2000;
const requestLogBuffer = [];
const appendRequestLog = (line = "") => {
  const trimmed = line.replace(/\s+$/, "");
  if (trimmed) {
    requestLogBuffer.push(`[${new Date().toISOString()}] ${trimmed}`);
    if (requestLogBuffer.length > MAX_LOG_BUFFER_LINES) {
      requestLogBuffer.shift();
    }
  }
};
const morganStream = {
  write: (line) => {
    appendRequestLog(line || "");
    process.stdout.write(line);
  },
};

const isCacheFresh = (entry) => entry && Date.now() - entry.ts < CACHE_MS;
const parseDateFromDayKey = (key = "") => {
  const match = key.match(/day-(\d{4})-(\d{2})-(\d{2})\.json$/);
  if (!match) return null;
  const [, year, month, day] = match;
  const iso = `${year}-${month}-${day}`;
  return { iso, date: new Date(`${iso}T00:00:00Z`) };
};

const app = express();
app.use(morgan("dev", { stream: morganStream }));
app.use(
  bodyParser.json({
    limit: "50mb",
  })
);

const parsePositiveInt = (value, fallback) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};
const clampLimit = (value, fallback, max) => {
  const parsed = parsePositiveInt(value, fallback);
  return Math.min(parsed, max);
};

const enableSafeIndexAppend = INDEX_SAFE_APPEND === "1";
const maxEventsPerDay = parsePositiveInt(INDEX_MAX_EVENTS, 2000);
const maxIndexRetries = parsePositiveInt(INDEX_SAFE_RETRIES, 5);
const faultProfiles = new Map(); // deviceId -> { failPutRate, httpCode, untilTs }

const signUploadToken = (payload) =>
  jwt.sign(payload, JWT_SECRET, { expiresIn: "15m" });
const verifyUploadToken = (token) => jwt.verify(token, JWT_SECRET);

const contentTypeToExtension = (contentType = "") => {
  switch ((contentType || "").toLowerCase()) {
    case "image/jpeg":
    case "image/jpg":
      return "jpg";
    case "image/png":
      return "png";
    case "video/mp4":
      return "mp4";
    case "video/avi":
    case "video/x-msvideo":
      return "avi";
    default:
      return "bin";
  }
};

const bucketForKind = (kind = "photos") =>
  kind === "clips" ? S3_BUCKET_CLIPS : S3_BUCKET_PHOTOS;

const publicBaseForKind = (kind = "photos") =>
  kind === "clips"
    ? S3_CLIPS_BASE.replace(/\/$/, "")
    : S3_PHOTOS_BASE.replace(/\/$/, "");

const buildObjectKey = (deviceId, objectKey, _kind = "photos", contentType, weightG = 0) => {
  if (objectKey && !objectKey.includes("..")) {
    return objectKey;
  }
  const ts = new Date().toISOString().replace(/[:.]/g, "-");
  const ext = contentTypeToExtension(contentType);
  const weightSuffix = weightG > 0 ? `_${weightG}g` : "";
  return `${deviceId}/${ts}-${nanoid(6)}${weightSuffix}.${ext}`;
};

const streamToBuffer = async (stream) => {
  if (!stream) return Buffer.from([]);
  if (Buffer.isBuffer(stream)) return stream;
  return await new Promise((resolve, reject) => {
    const chunks = [];
    stream.on("data", (chunk) => chunks.push(chunk));
    stream.on("end", () => resolve(Buffer.concat(chunks)));
    stream.on("error", reject);
  });
};

const streamToString = async (stream) => {
  const buffer = await streamToBuffer(stream);
  return buffer.toString("utf8");
};

const headObject = async (bucket, key) => {
  try {
    await galleryS3.send(new HeadObjectCommand({ Bucket: bucket, Key: key }));
    return true;
  } catch (err) {
    if (
      err?.name === "NotFound" ||
      err?.$metadata?.httpStatusCode === 404 ||
      err?.Code === "NoSuchKey"
    ) {
      return false;
    }
    throw err;
  }
};

const fetchObjectString = async (bucket, key) => {
  const out = await galleryS3.send(
    new GetObjectCommand({ Bucket: bucket, Key: key })
  );
  return await streamToString(out.Body);
};

const listObjects = async (bucket, prefix) => {
  const items = [];
  let ContinuationToken;
  do {
    const response = await galleryS3.send(
      new ListObjectsV2Command({
        Bucket: bucket,
        Prefix: prefix,
        ContinuationToken,
      })
    );
    (response.Contents || []).forEach((entry) =>
      items.push({
        Key: entry.Key,
        LastModified: entry.LastModified
          ? new Date(entry.LastModified)
          : undefined,
      })
    );
    ContinuationToken = response.IsTruncated
      ? response.NextContinuationToken
      : undefined;
  } while (ContinuationToken);
  return items;
};

const isoNoMillis = (value = new Date()) => {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  return date.toISOString().replace(/\.\d{3}Z$/, "Z");
};

const sanitizeDeviceId = (value) => {
  const trimmed = String(value ?? "").trim();
  const cleaned = trimmed.replace(/[^a-zA-Z0-9-_]/g, "");
  return cleaned || defaultDeviceId;
};

const devicePrefixFor = (deviceId, suffix = "") => {
  const base = galleryPrefix ? `${galleryPrefix}/${deviceId}` : `${deviceId}`;
  if (!suffix) {
    return base;
  }
  const normalized = suffix.replace(/^\/+/, "");
  return `${base}/${normalized}`;
};

const ensureTrailingSlash = (value = "") =>
  value.endsWith("/") ? value : `${value}/`;

const devicePrefixesForListing = (deviceId) => {
  const prefixes = [ensureTrailingSlash(devicePrefixFor(deviceId))];
  if (galleryPrefix) {
    prefixes.push(ensureTrailingSlash(deviceId));
  }
  return prefixes;
};

const baseFilenameFromKey = (key = "") => {
  if (!key) return "";
  const segments = key.split("/");
  return segments[segments.length - 1] || "";
};

const captureTimestampFromFilename = (filename = "", fallbackDate) => {
  const match = filename.match(
    /^(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2})-\d{3}Z/i
  );
  if (match) {
    return `${match[1].replace(/T(\d{2})-(\d{2})-(\d{2})/, "T$1:$2:$3")}Z`;
  }
  if (fallbackDate) {
    return isoNoMillis(fallbackDate);
  }
  return isoNoMillis();
};

const sumDirectorySize = async (targetPath) => {
  if (!targetPath) {
    return 0;
  }
  let stats;
  try {
    stats = await fs.stat(targetPath);
  } catch (err) {
    if (["ENOENT", "ENOTDIR", "EACCES"].includes(err.code)) {
      return 0;
    }
    throw err;
  }
  if (stats.isFile()) {
    return stats.size;
  }
  if (!stats.isDirectory()) {
    return 0;
  }

  let total = 0;
  try {
    const entries = await fs.readdir(targetPath, { withFileTypes: true });
    for (const entry of entries) {
      const entryPath = path.join(targetPath, entry.name);
      if (entry.isDirectory()) {
        total += await sumDirectorySize(entryPath);
      } else if (entry.isFile()) {
        try {
          const fileStats = await fs.stat(entryPath);
          total += fileStats.size;
        } catch (err) {
          if (!["ENOENT", "EACCES"].includes(err.code)) {
            throw err;
          }
        }
      }
    }
  } catch (err) {
    if (["ENOENT", "ENOTDIR", "EACCES"].includes(err.code)) {
      return 0;
    }
    throw err;
  }
  return total;
};

const computeLogFootprint = async () => {
  if (!logSnapshotRoots.length) {
    return 0;
  }
  let total = 0;
  for (const root of logSnapshotRoots) {
    total += await sumDirectorySize(root);
  }
  return total;
};

const checkDiskUsage = async () => {
  if (process.platform === "win32") {
    return {
      filesystem: null,
      mount: storageMountPath,
      totalBytes: null,
      usedBytes: null,
      freeBytes: null,
      note: "df_unavailable_on_windows",
    };
  }
  try {
    const target = storageMountPath || "/";
    const { stdout } = await execFileAsync("df", ["-k", target]);
    const lines = stdout.trim().split(/\r?\n/);
    if (lines.length >= 2) {
      const parts = lines[lines.length - 1].trim().split(/\s+/);
      if (parts.length >= 6) {
        const blockSize = 1024;
        const totalBlocks = Number(parts[1]) || 0;
        const usedBlocks = Number(parts[2]) || 0;
        const freeBlocks = Number(parts[3]) || 0;
        return {
          filesystem: parts[0],
          mount: parts[5],
          totalBytes: totalBlocks * blockSize,
          usedBytes: usedBlocks * blockSize,
          freeBytes: freeBlocks * blockSize,
        };
      }
    }
  } catch (err) {
    console.warn("[health] disk usage probe failed", err.message);
  }
  return {
    filesystem: null,
    mount: storageMountPath,
    totalBytes: null,
    usedBytes: null,
    freeBytes: null,
  };
};

const aggregateBucketStatsForPrefix = async (bucket, prefix) => {
  let continuationToken;
  let totalBytes = 0;
  let totalObjects = 0;
  do {
    const params = {
      Bucket: bucket,
      MaxKeys: 1000,
    };
    if (prefix) {
      params.Prefix = prefix;
    }
    if (continuationToken) {
      params.ContinuationToken = continuationToken;
    }
    const response = await galleryS3.send(new ListObjectsV2Command(params));
    const contents = response.Contents || [];
    totalObjects += contents.length;
    contents.forEach((entry) => {
      totalBytes += entry.Size || 0;
    });
    continuationToken = response.IsTruncated ? response.NextContinuationToken : undefined;
  } while (continuationToken);
  return { count: totalObjects, totalBytes };
};

const gatherDeviceStorageStats = async (bucket, deviceId) => {
  const prefixes = [`${devicePrefixFor(deviceId)}/`];
  if (galleryPrefix) {
    prefixes.push(`${deviceId}/`);
  }
  for (let idx = 0; idx < prefixes.length; idx += 1) {
    const prefix = prefixes[idx];
    const stats = await aggregateBucketStatsForPrefix(bucket, prefix);
    if (stats.count > 0 || idx === prefixes.length - 1) {
      return { ...stats, prefix };
    }
  }
  return { count: 0, totalBytes: 0, prefix: prefixes[prefixes.length - 1] };
};

const fetchDayIndexDocument = async (deviceId, isoDate) => {
  const prefixes = [`${devicePrefixFor(deviceId, "indices")}/`];
  if (galleryPrefix) {
    prefixes.push(`${deviceId}/indices/`);
  }

  if (isoDate) {
    for (const prefix of prefixes) {
      const key = `${prefix}day-${isoDate}.json`;
      try {
        const body = await fetchObjectString(galleryBucket, key);
        return { doc: JSON.parse(body), key };
      } catch (err) {
        if (
          err?.name !== "NoSuchKey" &&
          err?.$metadata?.httpStatusCode !== 404 &&
          err?.Code !== "NoSuchKey"
        ) {
          console.warn(`[health] failed to load day index ${key}`, err.message);
        }
      }
    }
  }

  for (const prefix of prefixes) {
    const objects = await listObjects(galleryBucket, prefix);
    const dayFiles = objects
      .filter((obj) => obj.Key && /day-\d{4}-\d{2}-\d{2}\.json$/.test(obj.Key))
      .sort((a, b) => {
        const aTime = a.LastModified ? a.LastModified.getTime() : 0;
        const bTime = b.LastModified ? b.LastModified.getTime() : 0;
        return aTime - bTime;
      });
    const latest = dayFiles[dayFiles.length - 1];
    if (!latest) {
      continue;
    }
    try {
      const body = await fetchObjectString(galleryBucket, latest.Key);
      return { doc: JSON.parse(body), key: latest.Key };
    } catch (err) {
      console.warn(`[health] failed to parse fallback day index ${latest.Key}`, err.message);
    }
  }

  return { doc: null, key: null };
};

const deriveVisitMetrics = async (deviceId) => {
  const todayIso = new Date().toISOString().slice(0, 10);
  let result = await fetchDayIndexDocument(deviceId, todayIso);
  if (!result.doc) {
    result = await fetchDayIndexDocument(deviceId);
  }
  const events = Array.isArray(result.doc?.events) ? result.doc.events : [];
  const visitsToday = result.doc && result.doc.date === todayIso ? events.length : 0;
  const lastEvent = events[events.length - 1];
  return {
    visitsToday,
    totalEvents: events.length,
    sourceDay: result.doc?.date || null,
    lastEventTs: lastEvent?.ts ? isoNoMillis(new Date(lastEvent.ts)) : null,
  };
};

const checkMinioHealth = async () => {
  const started = Date.now();
  try {
    await galleryS3.send(
      new ListObjectsV2Command({
        Bucket: galleryBucket,
        Prefix: galleryPrefix ? `${galleryPrefix}/` : undefined,
        MaxKeys: 1,
      })
    );
    return {
      status: "healthy",
      endpoint: MINIO_ENDPOINT || S3_ENDPOINT,
      latencyMs: Date.now() - started,
    };
  } catch (err) {
    return {
      status: "unhealthy",
      endpoint: MINIO_ENDPOINT || S3_ENDPOINT,
      latencyMs: Date.now() - started,
      error: err.message || "minio_unreachable",
    };
  }
};

const checkWsRelayHealth = async () => {
  const base = (WS_PUBLIC_BASE || "").trim();
  if (!base) {
    return { status: "unknown", endpoint: null };
  }
  let healthUrl;
  try {
    const parsed = new URL(base);
    parsed.pathname = `${parsed.pathname.replace(/\/+$/, "") || ""
      }/healthz`.replace(/\/{2,}/g, "/");
    healthUrl = parsed.toString();
  } catch (_err) {
    return { status: "unknown", endpoint: base, error: "invalid_url" };
  }
  if (!fetchImpl) {
    return { status: "unknown", endpoint: healthUrl, error: "fetch_unavailable" };
  }

  const started = Date.now();
  const supportsAbort = typeof AbortController === "function";
  const controller = supportsAbort ? new AbortController() : null;
  const timeout = controller ? setTimeout(() => controller.abort(), 3000) : null;
  try {
    const response = await fetchImpl(
      healthUrl,
      controller ? { signal: controller.signal } : undefined
    );
    if (timeout) {
      clearTimeout(timeout);
    }
    if (!response.ok) {
      return {
        status: "unhealthy",
        endpoint: healthUrl,
        statusCode: response.status,
        latencyMs: Date.now() - started,
      };
    }
    const payload = await response.json().catch(() => null);
    const rooms = Array.isArray(payload?.rooms) ? payload.rooms : [];
    const clients = rooms.reduce((sum, room) => sum + (room.clients || 0), 0);
    return {
      status: "healthy",
      endpoint: healthUrl,
      latencyMs: Date.now() - started,
      rooms: rooms.length,
      clients,
    };
  } catch (err) {
    return {
      status: err.name === "AbortError" ? "timeout" : "unreachable",
      endpoint: healthUrl,
      error: err.message,
    };
  } finally {
    if (timeout) {
      clearTimeout(timeout);
    }
  }
};

const buildGalleryObjectKey = (deviceId, filename) =>
  galleryPrefix ? `${galleryPrefix}/${deviceId}/${filename}` : `${deviceId}/${filename}`;

const pipeWebStream = (webStream, res) => {
  if (!webStream) {
    res.end();
    return;
  }
  if (typeof webStream.pipe === "function") {
    webStream.pipe(res);
    return;
  }
  try {
    Readable.from(webStream).pipe(res);
  } catch (_err) {
    res.end();
  }
};

const createGalleryProxyHandler = (bucketName, label = "photo") => async (req, res) => {
  const { deviceId, filename } = req.params;
  try {
    const objectKey = buildGalleryObjectKey(deviceId, filename);
    const getCommand = new GetObjectCommand({
      Bucket: bucketName,
      Key: objectKey,
    });
    const response = await galleryS3.send(getCommand);
    res.set("Content-Type", response.ContentType || "application/octet-stream");
    res.set("Cache-Control", "public, max-age=86400");
    if (response.ContentLength) {
      res.set("Content-Length", String(response.ContentLength));
    }
    response.Body.pipe(res);
  } catch (err) {
    console.error(
      `[asset-proxy] Error serving ${label} ${deviceId}/${filename}:`,
      err?.message || err
    );
    res.status(404).json({ error: `${label}_not_found` });
  }
};

const listRecentAssets = async ({ bucket, deviceId, limit = 20 }) => {
  const prefixes = devicePrefixesForListing(deviceId);
  let selectedObjects = [];
  let selectedPrefix = prefixes[prefixes.length - 1];

  for (let idx = 0; idx < prefixes.length; idx += 1) {
    const prefix = prefixes[idx];
    const objects = await listObjects(bucket, prefix);
    if (objects.length) {
      selectedObjects = objects;
      selectedPrefix = prefix;
      break;
    }
    if (idx === prefixes.length - 1) {
      selectedObjects = objects;
      selectedPrefix = prefix;
    }
  }

  const normalized = selectedObjects
    .map((entry) => {
      const relative = entry.Key?.startsWith(selectedPrefix)
        ? entry.Key.slice(selectedPrefix.length)
        : entry.Key;
      return {
        key: entry.Key,
        filename: baseFilenameFromKey(relative),
        relative,
        sizeBytes: entry.Size || 0,
        lastModified: entry.LastModified ? new Date(entry.LastModified) : null,
      };
    })
    .filter(
      (entry) =>
        Boolean(entry.filename) &&
        entry.relative &&
        !entry.relative.includes("/indices/") &&
        !entry.filename.endsWith(".json")
    );

  normalized.sort((a, b) => {
    const aTime = a.lastModified ? a.lastModified.getTime() : 0;
    const bTime = b.lastModified ? b.lastModified.getTime() : 0;
    if (aTime !== bTime) {
      return bTime - aTime;
    }
    return a.filename.localeCompare(b.filename);
  });

  const total = normalized.length;
  const items = normalized.slice(0, limit);
  return { total, items };
};

const tailRequestLogs = (count) => {
  if (!count || count <= 0) {
    return [];
  }
  const start = Math.max(requestLogBuffer.length - count, 0);
  return requestLogBuffer.slice(start);
};

const deleteObjectsForPrefix = async (bucket, prefix) => {
  let continuationToken;
  let deleted = 0;
  do {
    const { Contents = [], IsTruncated, NextContinuationToken } = await galleryS3.send(
      new ListObjectsV2Command({
        Bucket: bucket,
        Prefix: prefix,
        ContinuationToken: continuationToken,
      })
    );

    if (Contents.length) {
      for (let i = 0; i < Contents.length; i += 1000) {
        const batch = Contents.slice(i, i + 1000)
          .map((entry) => entry.Key)
          .filter(Boolean);
        if (!batch.length) continue;
        await galleryS3.send(
          new DeleteObjectsCommand({
            Bucket: bucket,
            Delete: {
              Objects: batch.map((Key) => ({ Key })),
              Quiet: true,
            },
          })
        );
        deleted += batch.length;
      }
    }

    continuationToken = IsTruncated ? NextContinuationToken : undefined;
  } while (continuationToken);
  return deleted;
};

const cleanupDeviceMedia = async (bucket, deviceId) => {
  const prefixes = devicePrefixesForListing(deviceId);
  let deleted = 0;
  for (const prefix of prefixes) {
    deleted += await deleteObjectsForPrefix(bucket, prefix);
  }
  return deleted;
};

const wsEventMetadata = (result) => ({
  attempted: Boolean(result?.attempted),
  delivered: Boolean(result?.delivered),
  reason: result?.reason || null,
});

const emitWsEvent = async (deviceId, payload) => {
  if (!wsRelayWsBase) {
    return { attempted: false, delivered: false, reason: "relay_unconfigured" };
  }
  return await new Promise((resolve) => {
    const relayUrl = new URL(wsRelayWsBase.toString());
    relayUrl.searchParams.set("deviceId", deviceId);
    let settled = false;
    const finish = (delivered, reason) => {
      if (settled) return;
      settled = true;
      resolve({
        attempted: true,
        delivered,
        reason: reason || null,
      });
    };

    const ws = new WebSocket(relayUrl.toString(), {
      handshakeTimeout: 3000,
    });
    const timeout = setTimeout(() => {
      try {
        ws.terminate();
      } catch (_err) {
        // ignore
      }
      finish(false, "timeout");
    }, 5000);

    ws.on("open", () => {
      try {
        ws.send(JSON.stringify(payload));
      } catch (err) {
        clearTimeout(timeout);
        finish(false, err?.message || "send_failed");
        return;
      }
      ws.close();
    });

    ws.on("close", () => {
      clearTimeout(timeout);
      finish(true);
    });

    ws.on("error", (err) => {
      clearTimeout(timeout);
      finish(false, err?.message || "ws_error");
    });
  });
};

const ensureDataDirectory = async () => {
  try {
    await fs.mkdir(dataDir, { recursive: true });
  } catch (err) {
    if (err.code !== "EEXIST") {
      throw err;
    }
  }
};

const readSettingsStore = async () => {
  if (cachedSettingsStore) {
    return cachedSettingsStore;
  }
  try {
    const raw = await fs.readFile(deviceSettingsPath, "utf8");
    cachedSettingsStore = JSON.parse(raw);
  } catch (err) {
    if (err.code === "ENOENT") {
      cachedSettingsStore = {};
    } else {
      console.warn("[settings] read failed", err.message || err);
      cachedSettingsStore = {};
    }
  }
  return cachedSettingsStore;
};

const writeSettingsStore = async (store) => {
  await ensureDataDirectory();
  await fs.writeFile(deviceSettingsPath, JSON.stringify(store, null, 2), "utf8");
  cachedSettingsStore = store;
};

const getDeviceSettingsSnapshot = async (deviceId) => {
  const store = await readSettingsStore();
  const entry = store[deviceId] || {};
  return {
    ...settingsDefaults,
    ...entry,
  };
};

const normalizeSettingsUpdate = (input = {}) => {
  const errors = [];
  const patch = {};

  if (Object.prototype.hasOwnProperty.call(input, "weightThreshold")) {
    const value = Number(input.weightThreshold);
    if (!Number.isFinite(value) || value < 1 || value > 500) {
      errors.push("weightThreshold must be between 1-500 grams");
    } else {
      patch.weightThreshold = Math.round(value);
    }
  }

  if (Object.prototype.hasOwnProperty.call(input, "cooldownSeconds")) {
    const value = Number(input.cooldownSeconds);
    if (!Number.isFinite(value) || value < 60 || value > 3600) {
      errors.push("cooldownSeconds must be between 60-3600 seconds");
    } else {
      patch.cooldownSeconds = Math.round(value);
    }
  }

  if (Object.prototype.hasOwnProperty.call(input, "cameraEnabled")) {
    if (typeof input.cameraEnabled !== "boolean") {
      errors.push("cameraEnabled must be boolean");
    } else {
      patch.cameraEnabled = input.cameraEnabled;
    }
  }

  return { patch, errors };
};

const persistDeviceSettings = async (deviceId, patch) => {
  const store = await readSettingsStore();
  const merged = {
    ...settingsDefaults,
    ...store[deviceId],
    ...patch,
    updatedAt: isoNoMillis(),
  };
  store[deviceId] = merged;
  await writeSettingsStore(store);
  return merged;
};

const tailPresignLogs = (lines) => {
  const buffer = tailRequestLogs(lines);
  return buffer.length ? buffer.join("\n") : "(no presign-api logs captured yet)";
};

const defaultLogServices = ["presign-api", "ws-relay", "minio"];

const parseServicesParam = (value) => {
  if (!value) return defaultLogServices;
  return String(value)
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
};

const composeFilePath = path.join(localStackDir, "docker-compose.yml");

const ensureComposeAvailable = async () => {
  try {
    await fs.access(composeFilePath);
    return true;
  } catch (_err) {
    return false;
  }
};

const runDockerComposeLogs = async (service, tailLines) => {
  const composeAvailable = await ensureComposeAvailable();
  if (!composeAvailable) {
    const err = new Error("compose_file_missing");
    err.code = "COMPOSE_FILE_MISSING";
    throw err;
  }
  try {
    const { stdout } = await execFileAsync(
      "docker",
      ["compose", "logs", "--tail", String(tailLines), service],
      {
        cwd: localStackDir,
        maxBuffer: 10 * 1024 * 1024,
      }
    );
    return stdout.trim();
  } catch (err) {
    throw err;
  }
};

const describeLogsError = (err) => {
  if (!err) return "unknown_error";
  if (err.code === "ENOENT") {
    return "docker_cli_unavailable";
  }
  if (err.code === "COMPOSE_FILE_MISSING") {
    return "compose_file_missing";
  }
  return err.stderr || err.message || String(err);
};

const collectLogsForServices = async (services, tailLines) => {
  const sections = [];
  for (const service of services) {
    if (service === "presign-api") {
      sections.push(
        `=== presign-api (last ${tailLines} lines) ===\n${tailPresignLogs(tailLines)}`
      );
      continue;
    }
    try {
      const text = await runDockerComposeLogs(service, tailLines);
      sections.push(
        `=== ${service} (last ${tailLines} lines) ===\n${text || "(no output)"}`
      );
    } catch (err) {
      sections.push(`=== ${service} ===\n! logs unavailable: ${describeLogsError(err)}`);
    }
  }
  return sections.join("\n\n");
};

const listRecentLogs = async (deviceId, limit) => {
  // For now this is a thin wrapper around docker-compose logs, not per-device.
  const services = defaultLogServices;
  const linesPerService = clampLimit(limit, 50, 500);
  const body = await collectLogsForServices(services, linesPerService);
  const entries = body
    .split("\n")
    .slice(-linesPerService)
    .map((line, idx) => ({
      id: `${deviceId}-${idx}`,
      ts: new Date().toISOString(),
      service: "stack",
      line,
    }));
  return { deviceId, entries };
};

const loadDayIndex = async (indexKey, baseDoc) => {
  const result = {
    doc: { ...baseDoc },
    etag: null,
    isNew: true,
  };
  try {
    const existing = await s3.send(
      new GetObjectCommand({
        Bucket: S3_BUCKET_INDICES,
        Key: indexKey,
      })
    );
    const body = await streamToBuffer(existing.Body);
    result.isNew = false;
    result.etag = existing.ETag;
    if (body.length) {
      try {
        const parsed = JSON.parse(body.toString());
        result.doc = {
          ...baseDoc,
          ...parsed,
          events: Array.isArray(parsed.events) ? parsed.events : [],
        };
        if (!result.doc.generatedTs) {
          result.doc.generatedTs = baseDoc.generatedTs;
        }
      } catch (parseErr) {
        console.warn("day index parse failed", {
          indexKey,
          error: parseErr?.message,
        });
        result.doc.events = [];
      }
    }
  } catch (err) {
    if (err.name !== "NoSuchKey" && err.$metadata?.httpStatusCode !== 404) {
      console.warn("day index read failed", err);
    }
  }
  return result;
};

const persistDayIndex = async (indexKey, doc, meta) => {
  const putParams = {
    Bucket: S3_BUCKET_INDICES,
    Key: indexKey,
    Body: JSON.stringify(doc, null, 2),
    ContentType: "application/json",
  };
  if (enableSafeIndexAppend) {
    if (meta.isNew) {
      putParams.IfNoneMatch = "*";
    } else if (meta.etag) {
      putParams.IfMatch = meta.etag;
    }
  }

  await s3.send(new PutObjectCommand(putParams));
};

// Write or append to the per-day manifest consumed by the gallery picker.
const updateDayIndex = async ({
  deviceId,
  key,
  kind,
  bytes,
  sha256,
}) => {
  const dateStr = new Date().toISOString().slice(0, 10);
  const indexKey = `${deviceId}/indices/day-${dateStr}.json`;
  const baseDoc = {
    deviceId,
    date: dateStr,
    generatedTs: Date.now(),
    events: [],
  };

  const relativeKey = key.startsWith(`${deviceId}/`)
    ? key.slice(deviceId.length + 1)
    : key;
  const dedupeKey = `${relativeKey}:${sha256 || ""}`;

  const applyEvent = (doc) => {
    if (!Array.isArray(doc.events)) {
      doc.events = [];
    }
    const existingIndex = doc.events.findIndex((event) => {
      const eventKey = `${event.key}:${event.sha256 || ""}`;
      return eventKey === dedupeKey;
    });

    const record = {
      id: nanoid(8),
      ts: Date.now(),
      key: relativeKey,
      kind,
      bytes,
      sha256,
    };

    if (existingIndex >= 0) {
      record.id = doc.events[existingIndex].id || record.id;
      doc.events[existingIndex] = {
        ...doc.events[existingIndex],
        ...record,
      };
    } else {
      doc.events.push(record);
    }

    if (doc.events.length > maxEventsPerDay) {
      doc.events.splice(0, doc.events.length - maxEventsPerDay);
    }

    doc.updatedTs = Date.now();
  };

  if (!enableSafeIndexAppend) {
    const meta = await loadDayIndex(indexKey, baseDoc);
    applyEvent(meta.doc);
    await persistDayIndex(indexKey, meta.doc, meta);
    return;
  }

  let attempts = 0;
  let lastError;
  while (attempts < maxIndexRetries) {
    attempts += 1;
    const meta = await loadDayIndex(indexKey, baseDoc);
    applyEvent(meta.doc);
    try {
      await persistDayIndex(indexKey, meta.doc, meta);
      return;
    } catch (err) {
      if (err.$metadata?.httpStatusCode === 412 || err.name === "PreconditionFailed") {
        lastError = err;
        continue;
      }
      throw err;
    }
  }

  console.warn("day index update exhausted retries", {
    indexKey,
    attempts: maxIndexRetries,
    error: lastError?.message,
  });
};

const buildHealthPayload = () => ({
  ok: true,
  env: environmentLabel,
  weakSecret: weakJwtSecret,
  indexSafeAppendEnabled: enableSafeIndexAppend,
  maxEventsPerDay,
  ts: Date.now(),
});

app.get("/v1/healthz", (_req, res) => {
  res.json(buildHealthPayload());
});

app.get("/healthz", (_req, res) => {
  res.json(buildHealthPayload());
});

app.get("/api/health", async (req, res) => {
  const deviceId = sanitizeDeviceId(req.query.deviceId || defaultDeviceId);
  const started = Date.now();
  try {
    const photosPromise = gatherDeviceStorageStats(bucketForKind("photos"), deviceId).catch(
      (err) => {
        console.error("[api:health] photo stats failed", err.message || err);
        return { count: 0, totalBytes: 0, prefix: null };
      }
    );
    const videosPromise = gatherDeviceStorageStats(bucketForKind("clips"), deviceId).catch(
      (err) => {
        console.error("[api:health] video stats failed", err.message || err);
        return { count: 0, totalBytes: 0, prefix: null };
      }
    );
    const logSizePromise = computeLogFootprint().catch((err) => {
      console.warn("[api:health] log footprint failed", err.message || err);
      return 0;
    });
    const diskPromise = checkDiskUsage();
    const visitsPromise = deriveVisitMetrics(deviceId).catch((err) => {
      console.warn("[api:health] visit metrics failed", err.message || err);
      return {
        visitsToday: 0,
        totalEvents: 0,
        sourceDay: null,
        lastEventTs: null,
      };
    });

    const [
      minioHealth,
      wsHealth,
      photos,
      videos,
      logSizeBytes,
      disk,
      visitMetrics,
    ] = await Promise.all([
      checkMinioHealth(),
      checkWsRelayHealth(),
      photosPromise,
      videosPromise,
      logSizePromise,
      diskPromise,
      visitsPromise,
    ]);

    const services = {
      minio: minioHealth,
      wsRelay: wsHealth,
    };

    const storage = {
      photos,
      videos,
      logs: {
        sizeBytes: logSizeBytes,
      },
      disk,
      freeSpaceBytes: typeof disk.freeBytes === "number" ? disk.freeBytes : null,
    };

    const metrics = {
      weight: {
        currentGrams: null,
        rollingAverageGrams: null,
        visitsToday: visitMetrics.visitsToday,
        lastEventTs: visitMetrics.lastEventTs,
        sourceDay: visitMetrics.sourceDay,
      },
      visits: {
        today: visitMetrics.visitsToday,
        totalEvents: visitMetrics.totalEvents,
        lastEventTs: visitMetrics.lastEventTs,
        sourceDay: visitMetrics.sourceDay,
      },
    };

    const hasFailure = Object.values(services).some(
      (svc) => svc.status && !["healthy", "unknown"].includes(svc.status)
    );

    res.json({
      status: hasFailure ? "degraded" : "healthy",
      deviceId,
      timestamp: isoNoMillis(),
      uptimeSeconds: Math.floor(process.uptime()),
      latencyMs: Date.now() - started,
      services,
      storage,
      metrics,
    });
  } catch (err) {
    console.error("[api:health] unexpected failure", err);
    res.status(500).json({ error: "health_unavailable" });
  }
});

// --- Devices / Telemetry / Connectivity / Logs summary endpoints ---

const parseDeviceFilter = (value) => {
  const raw = String(value || "").trim();
  if (!raw) return null;
  return raw.split(",").map((id) => sanitizeDeviceId(id)).filter(Boolean);
};

const buildDeviceSummaryRecord = (deviceId, healthSnapshot, wsHealth) => {
  const power = healthSnapshot?.storage?.photos || {};
  const batteryPercent = null; // Placeholder until firmware exposes battery stats via telemetry.
  const status =
    wsHealth?.status === "healthy"
      ? "online"
      : wsHealth?.status === "degraded"
        ? "degraded"
        : "offline";
  return {
    deviceId,
    status,
    batteryPercent,
    lastSeen: healthSnapshot?.metrics?.visits?.lastEventTs || null,
    photosCount: power.count || 0,
  };
};

app.get("/api/devices", async (req, res) => {
  // For now this is a thin wrapper around /api/health + ws-relay metrics.
  const filter = parseDeviceFilter(req.query.deviceId);
  const deviceIds = filter && filter.length ? filter : [defaultDeviceId];
  try {
    const [wsHealth, ...healthSnapshots] = await Promise.all([
      checkWsRelayHealth(),
      ...deviceIds.map((id) =>
        fetch(`${normalizedPublicBase}/api/health?deviceId=${encodeURIComponent(id)}`)
          .then((r) => (r.ok ? r.json() : null))
          .catch(() => null)
      ),
    ]);

    const devices = deviceIds.map((deviceId, idx) =>
      buildDeviceSummaryRecord(deviceId, healthSnapshots[idx], wsHealth)
    );

    res.json({ devices });
  } catch (err) {
    console.error("[api:devices] failed", err);
    res.status(500).json({ error: "devices_unavailable" });
  }
});

app.get("/api/telemetry", async (req, res) => {
  const deviceId = sanitizeDeviceId(req.query.deviceId || defaultDeviceId);
  const cached = deviceTelemetry.get(deviceId);
  if (cached) {
    return res.json(cached);
  }
  try {
    const healthResponse = await fetch(
      `${normalizedPublicBase}/api/health?deviceId=${encodeURIComponent(deviceId)}`
    );
    if (!healthResponse.ok) {
      return res.status(502).json({ error: "health_unavailable" });
    }
    const health = await healthResponse.json();
    const power = health.storage?.photos || {};
    const services = health.services || {};

    const telemetry = {
      deviceId,
      timestamp: health.timestamp || isoNoMillis(),
      packVoltage: null,
      solarWatts: null,
      loadWatts: null,
      internalTempC: null,
      signalStrengthDbm: null,
      batteryPercent: null,
      ambMiniMode: services.wsRelay?.status === "healthy" ? "idle" : "offline",
      storage: {
        photos: {
          count: power.count || 0,
          totalBytes: power.totalBytes || 0,
        },
      },
    };

    res.json(telemetry);
  } catch (err) {
    console.error("[api:telemetry] failed", err);
    res.status(500).json({ error: "telemetry_unavailable" });
  }
});

app.post("/api/telemetry/push", (req, res) => {
  const deviceId = sanitizeDeviceId(
    req.query.deviceId || req.body?.deviceId || defaultDeviceId
  );
  if (!deviceId) {
    return res.status(400).json({ error: "device_id_required" });
  }
  const payload = req.body && typeof req.body === "object" ? req.body : {};
  const nowIso = new Date().toISOString();
  const snapshot = {
    deviceId,
    timestamp:
      typeof payload.ts_ms === "number"
        ? new Date(payload.ts_ms).toISOString()
        : nowIso,
    updatedAt: nowIso,
    ...payload,
  };
  snapshot.deviceId = deviceId;
  snapshot.updatedAt = nowIso;
  deviceTelemetry.set(deviceId, snapshot);
  res.json({ ok: true });
});

app.get("/api/connectivity", async (req, res) => {
  const deviceId = sanitizeDeviceId(req.query.deviceId || defaultDeviceId);
  const started = Date.now();
  try {
    const wsHealth = await checkWsRelayHealth();
    const status =
      wsHealth?.status === "healthy"
        ? "online"
        : wsHealth?.status === "degraded"
          ? "degraded"
          : "offline";

    res.json({
      deviceId,
      status,
      averageRoundtripMs: wsHealth.latencyMs ?? null,
      recentFailures: wsHealth.errorCount ?? 0,
      lastSync: isoNoMillis(),
      latencyMs: Date.now() - started,
    });
  } catch (err) {
    console.error("[api:connectivity] failed", err);
    res.status(500).json({ error: "connectivity_unavailable" });
  }
});

const requireDeviceIdQuery = (value) => {
  const trimmed = String(value || "").trim();
  return trimmed.length > 0;
};

const extractDeviceId = (req) =>
  req.body?.deviceId ||
  req.body?.deviceID ||
  req.query?.deviceId ||
  req.query?.deviceID ||
  req.params?.deviceId;

const emitActionEvent = async (deviceId, event, message, extra = {}) =>
  wsEventMetadata(
    await emitWsEvent(deviceId, {
      type: "event",
      event,
      message,
      source: "api",
      ...extra,
    })
  );

app.post("/api/trigger/manual", async (req, res) => {
  const deviceIdRaw = extractDeviceId(req);
  if (!requireDeviceIdQuery(deviceIdRaw)) {
    return res.status(400).json({ error: "device_id_required" });
  }
  const deviceId = sanitizeDeviceId(deviceIdRaw);
  try {
    const websocket = await emitActionEvent(
      deviceId,
      "manual_trigger",
      "Manual trigger requested via dashboard"
    );
    res.json({
      success: true,
      deviceId,
      message: "Manual trigger sent",
      websocket,
    });
  } catch (err) {
    console.error("[api:trigger:manual] failed", err);
    res.status(500).json({ error: "manual_trigger_failed" });
  }
});

app.post("/api/snapshot", async (req, res) => {
  const deviceIdRaw = extractDeviceId(req);
  if (!requireDeviceIdQuery(deviceIdRaw)) {
    return res.status(400).json({ error: "device_id_required" });
  }
  const deviceId = sanitizeDeviceId(deviceIdRaw);
  try {
    const websocket = await emitActionEvent(
      deviceId,
      "snapshot_requested",
      "Snapshot requested via dashboard"
    );
    res.json({
      success: true,
      deviceId,
      message: "Snapshot command sent",
      websocket,
    });
  } catch (err) {
    console.error("[api:snapshot] failed", err);
    res.status(500).json({ error: "snapshot_failed" });
  }
});

app.post("/api/reboot", async (req, res) => {
  const deviceIdRaw = extractDeviceId(req);
  if (!requireDeviceIdQuery(deviceIdRaw)) {
    return res.status(400).json({ error: "device_id_required" });
  }
  const deviceId = sanitizeDeviceId(deviceIdRaw);
  try {
    const websocket = await emitActionEvent(
      deviceId,
      "reboot_requested",
      "Device reboot requested via dashboard"
    );
    res.json({
      success: true,
      deviceId,
      message: "Reboot command sent",
      websocket,
    });
  } catch (err) {
    console.error("[api:reboot] failed", err);
    res.status(500).json({ error: "reboot_failed" });
  }
});

app.get("/api/settings", async (req, res) => {
  if (!requireDeviceIdQuery(req.query.deviceId)) {
    return res.status(400).json({ error: "device_id_required" });
  }
  try {
    const deviceId = sanitizeDeviceId(req.query.deviceId);
    const settings = await getDeviceSettingsSnapshot(deviceId);
    res.json({ deviceId, settings });
  } catch (err) {
    console.error("[api:settings:get] failed", err);
    res.status(500).json({ error: "settings_unavailable" });
  }
});

app.post("/api/settings", async (req, res) => {
  const deviceIdRaw = extractDeviceId(req);
  if (!requireDeviceIdQuery(deviceIdRaw)) {
    return res.status(400).json({ error: "device_id_required" });
  }
  const updates = req.body?.settings;
  if (!updates || typeof updates !== "object") {
    return res.status(400).json({ error: "settings_payload_required" });
  }
  const deviceId = sanitizeDeviceId(deviceIdRaw);
  try {
    const { patch, errors } = normalizeSettingsUpdate(updates);
    if (errors.length) {
      return res.status(400).json({ error: "invalid_settings", details: errors });
    }
    if (!Object.keys(patch).length) {
      return res
        .status(400)
        .json({ error: "invalid_settings", details: ["No supported fields provided"] });
    }
    const saved = await persistDeviceSettings(deviceId, patch);
    res.json({ success: true, deviceId, settings: saved });
  } catch (err) {
    console.error("[api:settings:post] failed", err);
    res.status(500).json({ error: "settings_save_failed" });
  }
});

// Parse weight from filename like "2025-11-21T12-30-00-abc123_89g.jpg"
const parseWeightFromFilename = (filename) => {
  if (!filename) return 0;
  const match = filename.match(/_(\d+)g\.[a-z]+$/i);
  return match ? parseInt(match[1], 10) : 0;
};

const buildPhotoRecord = (item, deviceId) => {
  const filename = item.filename;
  const timestamp = captureTimestampFromFilename(filename, item.lastModified);
  const url = `${normalizedPublicBase}/gallery/${deviceId}/photo/${encodeURIComponent(
    filename
  )}`;
  const weightGrams = parseWeightFromFilename(filename);
  return {
    filename,
    url,
    timestamp,
    sizeBytes: item.sizeBytes,
    type: "photo",
    weightGrams,
  };
};

const buildVideoRecord = (item, deviceId) => {
  const filename = item.filename;
  const timestamp = captureTimestampFromFilename(filename, item.lastModified);
  const url = `${normalizedPublicBase}/gallery/${deviceId}/video/${encodeURIComponent(
    filename
  )}`;
  return {
    filename,
    url,
    timestamp,
    sizeBytes: item.sizeBytes,
    type: "clip",
  };
};

app.get("/api/photos", async (req, res) => {
  if (!requireDeviceIdQuery(req.query.deviceId)) {
    return res.status(400).json({ error: "device_id_required" });
  }
  const deviceId = sanitizeDeviceId(req.query.deviceId);
  const limit = clampLimit(req.query.limit, 20, 100);
  try {
    const { total, items } = await listRecentAssets({
      bucket: galleryBucket,
      deviceId,
      limit,
    });
    const photos = items.map((item) => buildPhotoRecord(item, deviceId));
    res.json({
      deviceId,
      total,
      count: photos.length,
      photos,
    });
  } catch (err) {
    console.error("[api:photos] failed to list photos", err);
    res.status(500).json({ error: "photos_list_failed" });
  }
});

app.get("/api/videos", async (req, res) => {
  if (!requireDeviceIdQuery(req.query.deviceId)) {
    return res.status(400).json({ error: "device_id_required" });
  }
  const deviceId = sanitizeDeviceId(req.query.deviceId);
  const limit = clampLimit(req.query.limit, 20, 100);
  try {
    const { total, items } = await listRecentAssets({
      bucket: bucketForKind("clips"),
      deviceId,
      limit,
    });
    const videos = items.map((item) => buildVideoRecord(item, deviceId));
    res.json({
      deviceId,
      total,
      count: videos.length,
      videos,
    });
  } catch (err) {
    console.error("[api:videos] failed to list videos", err);
    res.status(500).json({ error: "videos_list_failed" });
  }
});

const removeEventFromDayIndex = async (deviceId, filename) => {
  const timestampMatch = filename.match(/^(\d{4}-\d{2}-\d{2})/);
  if (!timestampMatch) return;
  const dateStr = timestampMatch[1];
  const indexKey = `${deviceId}/indices/day-${dateStr}.json`;

  const baseDoc = { deviceId, date: dateStr, generatedTs: Date.now(), events: [] };

  let attempts = 0;
  while (attempts < maxIndexRetries) {
    attempts += 1;
    const meta = await loadDayIndex(indexKey, baseDoc);
    if (meta.isNew && !meta.doc.events.length) {
      return;
    }

    const originalLen = meta.doc.events.length;
    meta.doc.events = meta.doc.events.filter(e => e.key !== filename);

    if (meta.doc.events.length === originalLen) {
      return;
    }

    meta.doc.updatedTs = Date.now();

    try {
      await persistDayIndex(indexKey, meta.doc, meta);
      return;
    } catch (err) {
      if (err.$metadata?.httpStatusCode === 412 || err.name === "PreconditionFailed") {
        continue;
      }
      throw err;
    }
  }
};

app.delete("/api/media/:filename", async (req, res) => {
  const { filename } = req.params;
  const deviceIdRaw = req.query.deviceId;

  if (!requireDeviceIdQuery(deviceIdRaw)) {
    return res.status(400).json({ error: "device_id_required" });
  }
  const deviceId = sanitizeDeviceId(deviceIdRaw);

  const isVideo = filename.toLowerCase().endsWith(".mp4") || filename.toLowerCase().endsWith(".mov");
  const bucket = isVideo ? bucketForKind("clips") : bucketForKind("photos");

  try {
    const key = buildGalleryObjectKey(deviceId, filename);

    await galleryS3.send(new DeleteObjectsCommand({
      Bucket: bucket,
      Delete: { Objects: [{ Key: key }], Quiet: true }
    }));

    await removeEventFromDayIndex(deviceId, filename);

    res.json({ success: true, deviceId, filename, deleted: true });
  } catch (err) {
    console.error("[api:media:delete] failed", err);
    res.status(500).json({ error: "delete_failed" });
  }
});





app.post("/api/cleanup/photos", async (req, res) => {
  const deviceIdRaw = extractDeviceId(req);
  if (!requireDeviceIdQuery(deviceIdRaw)) {
    return res.status(400).json({ error: "device_id_required" });
  }
  const deviceId = sanitizeDeviceId(deviceIdRaw);
  try {
    const deleted = await cleanupDeviceMedia(galleryBucket, deviceId);
    const websocket = await emitActionEvent(
      deviceId,
      "photos_deleted",
      `Deleted ${deleted} photo objects`
    );
    res.json({
      success: true,
      deviceId,
      deleted,
      message: `Deleted ${deleted} photo objects`,
      websocket,
    });
  } catch (err) {
    console.error("[api:cleanup:photos] failed", err);
    res.status(500).json({ error: "cleanup_photos_failed" });
  }
});

app.post("/api/cleanup/videos", async (req, res) => {
  const deviceIdRaw = extractDeviceId(req);
  if (!requireDeviceIdQuery(deviceIdRaw)) {
    return res.status(400).json({ error: "device_id_required" });
  }
  const deviceId = sanitizeDeviceId(deviceIdRaw);
  try {
    const deleted = await cleanupDeviceMedia(bucketForKind("clips"), deviceId);
    const websocket = await emitActionEvent(
      deviceId,
      "videos_deleted",
      `Deleted ${deleted} video objects`
    );
    res.json({
      success: true,
      deviceId,
      deleted,
      message: `Deleted ${deleted} video objects`,
      websocket,
    });
  } catch (err) {
    console.error("[api:cleanup:videos] failed", err);
    res.status(500).json({ error: "cleanup_videos_failed" });
  }
});

app.get("/api/logs", async (req, res) => {
  const services = parseServicesParam(req.query.services);
  const lines = clampLimit(req.query.lines, 300, 1000);
  try {
    const body = await collectLogsForServices(services, lines);
    res.set("Content-Type", "text/plain; charset=utf-8");
    res.send(body);
  } catch (err) {
    console.error("[api:logs] failed", err);
    res.status(500).json({ error: "logs_unavailable" });
  }
});

app.get("/api/logs/summary", async (req, res) => {
  const deviceId = sanitizeDeviceId(req.query.deviceId || defaultDeviceId);
  const limit = clampLimit(req.query.limit, 50, 500);
  try {
    const snapshot = await listRecentLogs(deviceId, limit);
    res.json({
      deviceId,
      limit,
      entries: snapshot.entries,
    });
  } catch (err) {
    console.error("[api:logs:summary] failed", err);
    res.status(500).json({ error: "logs_summary_unavailable" });
  }
});

app.post("/v1/presign/put", async (req, res) => {
  const { deviceId, objectKey, contentType, kind = "uploads", weightG = 0 } = req.body || {};
  if (!deviceId) {
    return res.status(400).json({ error: "deviceId is required" });
  }

  const resolvedKind = kind === "clips" ? "clips" : "photos";
  const key = buildObjectKey(deviceId, objectKey, resolvedKind, contentType, weightG);
  const uploadToken = signUploadToken({
    deviceId,
    key,
    contentType: contentType || "application/octet-stream",
    kind: resolvedKind,
  });

  return res.json({
    uploadUrl: `${PUBLIC_BASE.replace(/\/+$/, "")}/fput/${uploadToken}`,
    method: "PUT",
    headers: {
      "Content-Type": contentType || "application/octet-stream",
      Authorization: `Bearer ${uploadToken}`,
    },
    key,
    expiresIn: 900,
  });
});

app.get("/v1/presign/get", async (req, res) => {
  const { deviceId, objectKey, kind = "photos" } = req.query;
  if (!deviceId || !objectKey) {
    return res.status(400).json({ error: "deviceId and objectKey required" });
  }

  const resolvedKind = kind === "clips" ? "clips" : "photos";
  const key = objectKey.includes("/")
    ? objectKey
    : `${deviceId}/${objectKey}`;

  try {
    const command = new GetObjectCommand({
      Bucket: bucketForKind(resolvedKind),
      Key: key,
    });
    const url = await getSignedUrl(s3, command, { expiresIn: 900 });
    res.json({
      downloadUrl: url,
      expiresIn: 900,
      key,
      kind: resolvedKind,
    });
  } catch (err) {
    console.error("presign get failed", err);
    res.status(500).json({ error: "presign_get_failed" });
  }
});

// Shared logic for serving the latest gallery index
const serveLatestGalleryIndex = async (req, res, routeName = "gallery:get") => {
  const rawDeviceId = String(req.params.deviceId || "").trim();
  if (!rawDeviceId) {
    return res.status(400).json({ error: "device_id_required" });
  }
  const safeDeviceId = rawDeviceId.replace(/[^a-zA-Z0-9-_]/g, "");
  if (!safeDeviceId) {
    return res.status(400).json({ error: "invalid_device_id" });
  }

  const respond404 = () => {
    console.log(`[${routeName}] 404 device=${safeDeviceId} reason=no-index`);
    res.status(404).json({
      error: "not_found",
      bucket: galleryBucket,
      key: galleryPrefix ? `${galleryPrefix}/${safeDeviceId}/indices/` : `${safeDeviceId}/indices/`,
      message: "No index files",
    });
  };

  const sendKey = async (key, cache = true) => {
    const body = await fetchObjectString(galleryBucket, key);
    if (cache) {
      galleryCache.set(safeDeviceId, { key, ts: Date.now() });
    }

    // Parse and transform to gallery manifest format
    let dayIndex;
    try {
      dayIndex = JSON.parse(body);
    } catch (err) {
      console.error(`[${routeName}] Failed to parse day index`, err);
      throw err;
    }

    const captures = (dayIndex.events || []).map((event) => {
      // Use proxy endpoint instead of presigned URLs to avoid signature issues
      const photoUrl = `${PUBLIC_BASE}/gallery/${safeDeviceId}/photo/${event.key}`;

      // Parse timestamp from filename (format: 2025-10-30T01-56-34-417Z-h50dKV.jpg)
      // Swift's ISO8601 decoder expects format without fractional seconds: 2025-10-30T01:56:34Z
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

    const manifest = { captures };
    const manifestBody = JSON.stringify(manifest, null, 2);

    res.set("Content-Type", "application/json; charset=utf-8");
    res.set("Cache-Control", "public, max-age=30");
    res.status(200).send(manifestBody);
    console.log(
      `[${routeName}] 200 device=${safeDeviceId} key=${key} captures=${captures.length} len=${Buffer.byteLength(
        manifestBody,
        "utf8"
      )}`
    );
  };

  try {
    const cached = galleryCache.get(safeDeviceId);
    if (isCacheFresh(cached)) {
      try {
        await sendKey(cached.key, false);
        return;
      } catch (_err) {
        galleryCache.delete(safeDeviceId);
      }
    }

    // Try direct captures_index.json first (legacy)
    const directKey = galleryPrefix ? `${galleryPrefix}/${safeDeviceId}/captures_index.json` : `${safeDeviceId}/captures_index.json`;
    const hasDirect = await headObject(galleryBucket, directKey);
    if (hasDirect) {
      await sendKey(directKey);
      return;
    }

    // Fall back to finding the latest day index
    const prefix = galleryPrefix ? `${galleryPrefix}/${safeDeviceId}/indices/` : `${safeDeviceId}/indices/`;
    const objects = await listObjects(galleryBucket, prefix);
    const dayFiles = objects
      .filter((obj) => obj.Key && /day-\d{4}-\d{2}-\d{2}\.json$/.test(obj.Key))
      .map((obj) => {
        const parsed = parseDateFromDayKey(obj.Key);
        return {
          key: obj.Key,
          parsed,
          last: obj.LastModified || null,
        };
      });

    if (!dayFiles.length) {
      respond404();
      return;
    }

    dayFiles.sort((a, b) => {
      if (a.parsed && b.parsed) {
        return a.parsed.iso.localeCompare(b.parsed.iso);
      }
      if (a.parsed) return 1;
      if (b.parsed) return -1;
      if (a.last && b.last) {
        return a.last - b.last;
      }
      if (a.last) return 1;
      if (b.last) return -1;
      return 0;
    });
    const latestKey = dayFiles[dayFiles.length - 1].key;
    await sendKey(latestKey);
  } catch (err) {
    console.error(`[${routeName}] 500`, { device: safeDeviceId, msg: err?.message });
    res.status(500).json({ error: "server_error" });
  }
};

app.get("/gallery/:deviceId/indices/latest.json", (req, res) => {
  serveLatestGalleryIndex(req, res, "gallery:latest");
});

app.get("/gallery/:deviceId/captures_index.json", (req, res) => {
  serveLatestGalleryIndex(req, res, "gallery:legacy");
});

// Photo/video proxy endpoints - stream assets over HTTP without exposing presigned URLs
app.get("/gallery/:deviceId/photo/:filename", createGalleryProxyHandler(galleryBucket, "photo"));
app.get(
  "/gallery/:deviceId/video/:filename",
  createGalleryProxyHandler(bucketForKind("clips"), "video")
);

app.get("/camera/stream", async (_req, res) => {
  if (cameraStreamUrl && fetchImpl) {
    try {
      const controller = typeof AbortController !== "undefined" ? new AbortController() : null;
      const upstream = await fetchImpl(cameraStreamUrl, {
        signal: controller?.signal,
        cache: "no-store",
      });
      if (controller) {
        setTimeout(() => controller.abort(), 15000);
      }
      if (upstream.ok && upstream.body) {
        const contentType =
          upstream.headers.get("content-type") || "application/octet-stream";
        res.set("Content-Type", contentType);
        res.set("Cache-Control", "no-store, must-revalidate");
        res.status(200);
        pipeWebStream(upstream.body, res);
        return;
      }
      throw new Error(`upstream_status_${upstream.status}`);
    } catch (err) {
      console.warn("[camera:stream] upstream unavailable", err?.message || err);
    }
  }
  res
    .status(503)
    .set("Cache-Control", "no-store")
    .set("Retry-After", "2")
    .json({
      error: "camera_unavailable",
      message: cameraStreamUrl
        ? "Camera stream unreachable"
        : "Camera stream not configured",
    });
});

app.get("/v1/discovery/:deviceId", (req, res) => {
  const { deviceId } = req.params;
  const wsBase = WS_PUBLIC_BASE || PUBLIC_BASE;
  res.json({
    deviceId,
    fw_version: "0.0.0-local",
    video: {
      thumb_base: `${publicBaseForKind("photos")}/${deviceId}/`,
      clip_base: `${publicBaseForKind("clips")}/${deviceId}/`,
      retention: { clips_days: 1, photos_days: 30 },
    },
    signal_ws: wsBase.replace(/^http/, "ws").replace(/\/$/, ""),
    presign_base: `${PUBLIC_BASE.replace(/\/+$/, "")}/v1/presign`,
    ota_base: `${OTA_BASE.replace(/\/+$/, "")}`,
    step: "A1.1-local",
    cap: ["upload_immediate", "ram_retry_queue", "save_to_photos"],
    services: ["weight", "motion", "visit", "camera", "ota", "logs"],
  });
});

app.post("/v1/test/faults", (req, res) => {
  const { deviceId, failPutRate = 0, httpCode = 500, untilTs } = req.body || {};
  if (!deviceId) {
    return res.status(400).json({ error: "deviceId required" });
  }
  if (failPutRate < 0 || failPutRate > 1) {
    return res.status(400).json({ error: "failPutRate must be between 0-1" });
  }

  if (!untilTs || Number.isNaN(Number(untilTs))) {
    faultProfiles.delete(deviceId);
    return res.json({ deviceId, disabled: true });
  }

  faultProfiles.set(deviceId, {
    failPutRate,
    httpCode,
    untilTs: Number(untilTs),
  });
  res.json({ deviceId, failPutRate, httpCode, untilTs });
});

app.get("/v1/test/faults", (_req, res) => {
  const list = Array.from(faultProfiles.entries()).map(
    ([deviceId, profile]) => ({ deviceId, ...profile })
  );
  res.json(list);
});

const shouldFailUpload = (deviceId) => {
  const profile = faultProfiles.get(deviceId);
  if (!profile) return { fail: false };
  if (Date.now() > profile.untilTs) {
    faultProfiles.delete(deviceId);
    return { fail: false };
  }
  const roll = Math.random();
  if (roll <= profile.failPutRate) {
    return { fail: true, httpCode: profile.httpCode || 500 };
  }
  return { fail: false };
};

app.put("/fput/:token", async (req, res) => {
  const token = req.params.token;
  try {
    const payload = verifyUploadToken(token);
    const { deviceId, key, contentType, kind = "misc" } = payload;

    const fail = shouldFailUpload(deviceId);
    if (fail.fail) {
      return res
        .status(fail.httpCode || 500)
        .json({ error: "simulated_failure", code: fail.httpCode || 500 });
    }

    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", async () => {
      try {
        const body = Buffer.concat(chunks);
        const shaHex = crypto.createHash("sha256").update(body).digest("hex");
        await s3.send(
          new PutObjectCommand({
            Bucket: bucketForKind(kind),
            Key: key,
            Body: body,
            ContentType: contentType || req.headers["content-type"],
          })
        );
        try {
          await updateDayIndex({
            deviceId,
            key,
            kind,
            bytes: body.length,
            sha256: shaHex,
          });
        } catch (err) {
          console.warn("day index update failed", err);
        }
        res.status(204).send();
      } catch (err) {
        console.error("PUT proxy failed", err);
        res.status(500).json({ error: "upload_failed" });
      }
    });
  } catch (err) {
    console.error("invalid upload token", err);
    res.status(401).json({ error: "invalid_token" });
  }
});

console.log(`[gallery:init] bucket=${galleryBucket} prefix=${galleryPrefix}`);

app.listen(PORT, "0.0.0.0", () => {
  console.log(`presign api listening on :${PORT}`);
});
