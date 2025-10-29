#!/usr/bin/env node
/**
 * Generate a presigned HTTPS PUT URL for Cloudflare R2 uploads.
 *
 * Usage:
 *   node backend/presign_put.js --device dev1 --event evt-2025-10-12T07:31:22Z-abc123 --thing thumb [--expires 900]
 *
 * Required environment:
 *   R2_ACCOUNT_ID, R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY
 * Optional:
 *   R2_ENDPOINT (defaults to https://<account>.r2.cloudflarestorage.com)
 *
 * Install deps:
 *   npm install --save-dev @aws-sdk/client-s3 @aws-sdk/s3-request-presigner
 */

const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

const args = parseArgs(process.argv.slice(2));
const thing = args.thing;
const eventId = args.event;
const deviceId = args.device;
const expires = Number(args.expires ?? 900);

if (!deviceId || !eventId || !thing || !["thumb", "clip"].includes(thing)) {
  usage("device, event and thing (thumb|clip) are required");
}

const {
  R2_ACCOUNT_ID,
  R2_BUCKET,
  R2_ACCESS_KEY_ID,
  R2_SECRET_ACCESS_KEY,
  R2_ENDPOINT
} = process.env;

if (!R2_ACCOUNT_ID || !R2_BUCKET || !R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY) {
  usage("Missing R2_* environment variables (ACCOUNT_ID, BUCKET, ACCESS_KEY_ID, SECRET_ACCESS_KEY)");
}

const endpoint = R2_ENDPOINT ?? `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`;
const region = "auto";

const { key, contentType, tagging } = buildKey({ deviceId, eventId, thing });

const client = new S3Client({
  region,
  endpoint,
  credentials: {
    accessKeyId: R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY
  }
});

const command = new PutObjectCommand({
  Bucket: R2_BUCKET,
  Key: key,
  ContentType: contentType,
  Tagging: tagging
});

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

async function main() {
  const url = await getSignedUrl(client, command, { expiresIn: expires });
  console.log(JSON.stringify({
    method: "PUT",
    bucket: R2_BUCKET,
    key,
    contentType,
    tagging,
    expiresInSeconds: expires,
    url
  }, null, 2));
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (next && !next.startsWith("--")) {
      out[key] = next;
      i++;
    } else {
      out[key] = true;
    }
  }
  return out;
}

function usage(message) {
  if (message) {
    console.error(`Error: ${message}`);
  }
  console.error("Usage: node backend/presign_put.js --device dev1 --event evt-... --thing thumb|clip [--expires 900]");
  process.exit(1);
}

function buildKey({ deviceId, eventId, thing }) {
  const sanitizedEvent = eventId.trim();
  const trimmed = sanitizedEvent.startsWith("evt-") ? sanitizedEvent.slice(4) : sanitizedEvent;
  const lastDash = trimmed.lastIndexOf("-");
  const isoPart = lastDash > 0 ? trimmed.slice(0, lastDash) : trimmed;
  const datePart = isoPart.slice(0, 10);
  const [yyyy, mm, dd] = (datePart.split("-").length === 3) ? datePart.split("-") : deriveDateFallback();

  const basePath = thing === "thumb" ? "photos" : "clips";
  const filename = thing === "thumb" ? "thumb.jpg" : "clip.mp4";
  const key = `u/${deviceId}/${basePath}/${yyyy}/${mm}/${dd}/${sanitizedEvent}/${filename}`;
  const contentType = thing === "thumb" ? "image/jpeg" : "video/mp4";
  const tagging = `type=${thing === "thumb" ? "photo" : "clip"}`;
  return { key, contentType, tagging };
}

function deriveDateFallback() {
  const now = new Date();
  const yyyy = String(now.getUTCFullYear()).padStart(4, "0");
  const mm = String(now.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(now.getUTCDate()).padStart(2, "0");
  return [yyyy, mm, dd];
}
