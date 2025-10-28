#!/usr/bin/env node
/**
 * Generate a day index JSON file from one or more meta.json inputs.
 *
 * Example:
 *   node tools/demo-index-day.js --device dev1 --date 2025-10-12 \
 *     --meta sample/meta1.json --meta sample/meta2.json \
 *     --out schemas/samples/day-2025-10-12.json
 *
 * If no --meta files are provided, a synthetic sample event is produced.
 */

const fs = require("fs");
const path = require("path");

const args = parseArgs(process.argv.slice(2));

const deviceId = args.device ?? "dev1";
const date = args.date ?? new Date().toISOString().slice(0, 10);
const metas = Array.isArray(args.meta) ? args.meta : (args.meta ? [args.meta] : []);
const outPath = args.out ?? path.join("schemas", "samples", `day-${date}.json`);

const calendarParts = date.split("-");
if (calendarParts.length !== 3) {
  console.error(`Invalid --date ${date}, expected YYYY-MM-DD`);
  process.exit(1);
}
const [year, month, day] = calendarParts;

const events = metas.length > 0 ? metas.map((m) => loadMeta(m, { year, month, day })) : [syntheticEvent(deviceId, { year, month, day })];

const index = {
  device_id: deviceId,
  date,
  generated_ts: Math.floor(Date.now() / 1000),
  events
};

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(index, null, 2));
console.log(`Wrote ${outPath}`);

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (next && !next.startsWith("--")) {
      if (out[key]) {
        out[key] = Array.isArray(out[key]) ? [...out[key], next] : [out[key], next];
      } else {
        out[key] = next;
      }
      i++;
    } else {
      out[key] = true;
    }
  }
  return out;
}

function loadMeta(file, parts) {
  const raw = JSON.parse(fs.readFileSync(file, "utf-8"));
  const thumbUrl = raw.thumb_url ?? placeholderUrl("photos", raw.event_id, parts);
  const clipUrl = raw.clip_url ?? placeholderUrl("clips", raw.event_id, parts);
  return {
    event_id: raw.event_id,
    ts: raw.ts,
    local_time: raw.local_time ?? new Date(raw.ts * 1000).toISOString(),
    policy: raw.policy,
    thumb: {
      url: thumbUrl,
      bytes: raw.thumb?.bytes ?? 0,
      sha256: raw.sha256_thumb
    },
    clip: {
      available: raw.policy === "immediate" ? true : Boolean(raw.sha256_clip && (raw.clip?.bytes ?? 0) > 0),
      url: clipUrl,
      bytes: raw.clip?.bytes ?? 0,
      sha256: raw.sha256_clip
    },
    sensors: raw.sensors ?? []
  };
}

function syntheticEvent(deviceId, parts) {
  const isoDate = `${parts.year}-${parts.month}-${parts.day}`;
  const eventId = `evt-${isoDate}T12:00:00Z-demo123`;
  return {
    event_id: eventId,
    ts: Math.floor(Date.now() / 1000),
    local_time: `${isoDate}T12:00:00Z`,
    policy: "immediate",
    thumb: {
      url: placeholderUrl("photos", eventId, parts),
      bytes: 102400,
      sha256: "0".repeat(64)
    },
    clip: {
      available: true,
      url: placeholderUrl("clips", eventId, parts),
      bytes: 2_048_000,
      sha256: "1".repeat(64)
    },
    sensors: ["pir"]
  };
}

function placeholderUrl(kind, eventId, parts) {
  const base = kind === "photos" ? "photos" : "clips";
  const filename = kind === "photos" ? "thumb.jpg" : "clip.mp4";
  return `https://cdn.skyfeeder.io/u/${encodeURIComponent(deviceId)}/${base}/${parts.year}/${parts.month}/${parts.day}/${eventId}/${filename}`;
}
