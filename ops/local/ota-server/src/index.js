import dotenv from "dotenv";
dotenv.config();

import express from "express";
import bodyParser from "body-parser";
import morgan from "morgan";
import path from "path";
import { fileURLToPath } from "url";

const {
  PORT = 8090,
  OTA_MAX_BOOT_FAILS = 3,
} = process.env;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(morgan("dev"));
app.use(bodyParser.json());

const firmwareStatus = new Map(); // deviceId -> { version, slot, bootCount, status, updatedTs }

app.use(express.static(path.join(__dirname, "../public")));

app.get("/healthz", (_req, res) => {
  res.json({ ok: true, firmwareStatus: Array.from(firmwareStatus.entries()) });
});

app.get("/v1/ota/status", (_req, res) => {
  res.json(
    Array.from(firmwareStatus.entries()).map(([deviceId, info]) => ({
      deviceId,
      ...info,
    }))
  );
});

app.post("/v1/ota/heartbeat", (req, res) => {
  const { deviceId, version, slot, bootCount = 0, status = "boot" } = req.body || {};
  if (!deviceId || !version) {
    return res.status(400).json({ error: "deviceId and version required" });
  }

  const entry = firmwareStatus.get(deviceId) || {};
  const updated = {
    version,
    slot: slot ?? null,
    bootCount,
    status,
    updatedTs: Date.now(),
  };
  firmwareStatus.set(deviceId, updated);

  const rollback = status === "failed" || bootCount >= Number(OTA_MAX_BOOT_FAILS);
  res.json({ rollback, ackTs: Date.now() });
});

app.listen(PORT, () => {
  console.log(`ota server listening on :${PORT}`);
});
