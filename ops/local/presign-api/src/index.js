import dotenv from "dotenv";
dotenv.config();

import express from "express";
import bodyParser from "body-parser";
import morgan from "morgan";
import { nanoid } from "nanoid";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
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
  OTA_BASE = "http://localhost:9180",
  ENV_TIER,
  INDEX_SAFE_APPEND,
  INDEX_MAX_EVENTS,
  INDEX_SAFE_RETRIES,
} = process.env;

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

const app = express();
app.use(morgan("dev"));
app.use(
  bodyParser.json({
    limit: "50mb",
  })
);

const parsePositiveInt = (value, fallback) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
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

const buildObjectKey = (deviceId, objectKey, _kind = "photos", contentType) => {
  if (objectKey && !objectKey.includes("..")) {
    return objectKey;
  }
  const ts = new Date().toISOString().replace(/[:.]/g, "-");
  const ext = contentTypeToExtension(contentType);
  return `${deviceId}/${ts}-${nanoid(6)}.${ext}`;
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

app.post("/v1/presign/put", async (req, res) => {
  const { deviceId, objectKey, contentType, kind = "uploads" } = req.body || {};
  if (!deviceId) {
    return res.status(400).json({ error: "deviceId is required" });
  }

  const resolvedKind = kind === "clips" ? "clips" : "photos";
  const key = buildObjectKey(deviceId, objectKey, resolvedKind, contentType);
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

app.listen(PORT, () => {
  console.log(`presign api listening on :${PORT}`);
});
