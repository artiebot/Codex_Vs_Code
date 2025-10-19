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
  JWT_SECRET = "dev-only",
  PUBLIC_BASE = `http://localhost:${PORT}`,
  S3_PHOTOS_BASE = "http://localhost:9200/photos",
  S3_CLIPS_BASE = "http://localhost:9200/clips",
  WS_PUBLIC_BASE = "http://localhost:8081",
  OTA_BASE = "http://localhost:9180",
} = process.env;

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

  let indexDoc = {
    deviceId,
    date: dateStr,
    generatedTs: Date.now(),
    events: [],
  };

  try {
    const existing = await s3.send(
      new GetObjectCommand({
        Bucket: S3_BUCKET_INDICES,
        Key: indexKey,
      })
    );
    const body = await streamToBuffer(existing.Body);
    if (body.length) {
      indexDoc = JSON.parse(body.toString());
      if (!Array.isArray(indexDoc.events)) {
        indexDoc.events = [];
      }
    }
  } catch (err) {
    if (err.name !== "NoSuchKey" && err.$metadata?.httpStatusCode !== 404) {
      console.warn("day index read failed", err);
    }
  }

  indexDoc.updatedTs = Date.now();
  const relativeKey = key.startsWith(`${deviceId}/`) ? key.slice(deviceId.length + 1) : key;
  indexDoc.events.push({
    id: nanoid(8),
    ts: Date.now(),
    key: relativeKey,
    kind,
    bytes,
    sha256,
  });

  await s3.send(
    new PutObjectCommand({
      Bucket: S3_BUCKET_INDICES,
      Key: indexKey,
      Body: JSON.stringify(indexDoc, null, 2),
      ContentType: "application/json",
    })
  );
};

app.get("/healthz", (_req, res) => {
  res.json({ ok: true });
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
