import dotenv from "dotenv";
dotenv.config();

import express from "express";
import bodyParser from "body-parser";
import morgan from "morgan";
import path from "path";
import { fileURLToPath } from "url";
import { promises as fs } from "fs";

const {
  PORT = 8090,
  OTA_MAX_BOOT_FAILS = 3,
  OTA_DATA_DIR,
} = process.env;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DATA_DIR = OTA_DATA_DIR || path.join(__dirname, "../data");
const STATUS_FILE = path.join(DATA_DIR, "ota_status.json");

const app = express();
app.use(morgan("dev"));
app.use(bodyParser.json());

const firmwareStatus = new Map(); // deviceId -> { version, slot, bootCount, status, updatedTs }
let statusLoaded = false;

const statusEntries = () =>
  Array.from(firmwareStatus.entries()).map(([deviceId, info]) => ({
    deviceId,
    ...info,
  }));

const loadFirmwareStatus = async () => {
  if (statusLoaded) {
    return;
  }
  try {
    const raw = await fs.readFile(STATUS_FILE, "utf8");
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) {
      firmwareStatus.clear();
      for (const entry of parsed) {
        if (entry?.deviceId) {
          const { deviceId, ...rest } = entry;
          firmwareStatus.set(deviceId, rest);
        }
      }
    }
    statusLoaded = true;
  } catch (err) {
    if (err?.code !== "ENOENT") {
      console.warn("failed to load persisted OTA status", err);
    }
    statusLoaded = true;
  }
};

const persistFirmwareStatus = async () => {
  try {
    await fs.mkdir(DATA_DIR, { recursive: true });
    const serialized = JSON.stringify(statusEntries(), null, 2);
    await fs.writeFile(STATUS_FILE, serialized);
  } catch (err) {
    console.warn("failed to persist firmware status", err);
  }
};

await loadFirmwareStatus();

app.use(express.static(path.join(__dirname, "../public")));

app.get("/healthz", async (_req, res) => {
  await loadFirmwareStatus();
  res.json({ ok: true, firmwareStatus: statusEntries() });
});

app.get("/v1/ota/status", async (_req, res) => {
  await loadFirmwareStatus();
  res.json(statusEntries());
});

app.post("/v1/ota/heartbeat", async (req, res) => {
  await loadFirmwareStatus();
  const { deviceId, version, slot, bootCount = 0, status = "boot" } = req.body || {};
  if (!deviceId || !version) {
    return res.status(400).json({ error: "deviceId and version required" });
  }

  const updated = {
    version,
    slot: slot ?? null,
    bootCount,
    status,
    updatedTs: Date.now(),
  };
  firmwareStatus.set(deviceId, updated);

  await persistFirmwareStatus();

  const rollback = status === "failed" || bootCount >= Number(OTA_MAX_BOOT_FAILS);
  res.json({ rollback, ackTs: Date.now() });
});

app.listen(PORT, () => {
  console.log(`ota server listening on :${PORT}`);
});
