import dotenv from "dotenv";
dotenv.config();

import http from "http";
import url from "url";
import express from "express";
import jwt from "jsonwebtoken";
import morgan from "morgan";
import { WebSocketServer } from "ws";

const {
  PORT = 8081,
  JWT_SECRET = "dev-only",
  HEARTBEAT_INTERVAL_MS = 30000,
} = process.env;

const app = express();
app.use(morgan("dev"));

const rooms = new Map(); // deviceId -> Set<Socket>
let messageCount = 0;

const listRooms = () =>
  Array.from(rooms.entries()).map(([deviceId, clients]) => ({
    deviceId,
    clients: clients.size,
  }));

app.get("/healthz", (_req, res) => {
  res.json({ ok: true, rooms: listRooms() });
});

app.get("/rooms", (_req, res) => {
  res.json(listRooms());
});

app.get("/v1/metrics", (_req, res) => {
  const totalClients = Array.from(rooms.values()).reduce(
    (sum, set) => sum + set.size,
    0
  );
  res.json({
    rooms: listRooms(),
    totalClients,
    messageCount,
    ts: Date.now(),
  });
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

const attachClientToRoom = (deviceId, ws) => {
  if (!rooms.has(deviceId)) {
    rooms.set(deviceId, new Set());
  }
  rooms.get(deviceId).add(ws);
};

const removeClientFromRoom = (deviceId, ws) => {
  if (!rooms.has(deviceId)) return;
  const set = rooms.get(deviceId);
  set.delete(ws);
  if (set.size === 0) {
    rooms.delete(deviceId);
  }
};

const broadcast = (deviceId, payload, sender) => {
  const set = rooms.get(deviceId);
  if (!set) return;
  for (const client of set) {
    if (client !== sender && client.readyState === client.OPEN) {
      client.send(payload);
    }
  }
};

const verifyToken = (token) => jwt.verify(token, JWT_SECRET);

wss.on("connection", (ws, request) => {
  const { query } = url.parse(request.url, true);
  const token = query?.token || request.headers["sec-websocket-protocol"];
  if (!token) {
    ws.close(1008, "token required");
    return;
  }

  let payload;
  try {
    payload = verifyToken(token.split(",").pop());
  } catch (err) {
    console.error("invalid ws token", err);
    ws.close(1008, "invalid token");
    return;
  }

  const deviceId = payload.deviceId;
  if (!deviceId) {
    ws.close(1008, "deviceId missing");
    return;
  }

  ws.deviceId = deviceId;
  ws.isAlive = true;
  attachClientToRoom(deviceId, ws);
  console.log(`ws client joined device ${deviceId}, clients=${rooms.get(deviceId).size}`);

  ws.send(
    JSON.stringify({
      type: "system",
      message: "connected",
      deviceId,
      rooms: listRooms(),
    })
  );

  ws.on("message", (data) => {
    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch (err) {
      ws.send(JSON.stringify({ type: "error", message: "invalid_json" }));
      return;
    }

    if (msg.type === "ping") {
      ws.send(JSON.stringify({ type: "pong", ts: Date.now() }));
      return;
    }

    if (!msg.type) {
      ws.send(JSON.stringify({ type: "error", message: "missing_type" }));
      return;
    }

    const envelope = {
      ...msg,
      deviceId,
      ts: msg.ts || Date.now(),
    };
    messageCount += 1;
    broadcast(deviceId, JSON.stringify(envelope), ws);
  });

  ws.on("pong", () => {
    ws.isAlive = true;
  });

  ws.on("close", (code, reason) => {
    removeClientFromRoom(deviceId, ws);
    const remaining = rooms.get(deviceId)?.size || 0;
    console.log(
      `ws client left device ${deviceId}, code=${code}, reason=${reason?.toString?.() ||
        ""}, clients=${remaining}`
    );
  });
});

const pingInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      ws.terminate();
      return;
    }
    ws.isAlive = false;
    ws.ping();
  });
}, Number(HEARTBEAT_INTERVAL_MS));

wss.on("close", () => {
  clearInterval(pingInterval);
});

server.listen(PORT, () => {
  console.log(`ws-relay listening on :${PORT}`);
});
