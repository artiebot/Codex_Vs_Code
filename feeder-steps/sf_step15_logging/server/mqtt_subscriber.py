import json
import os
import sqlite3
import threading
import time
from typing import List, Tuple

import paho.mqtt.client as mqtt
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, JSONResponse

DB_PATH = os.environ.get("SKYFEEDER_DB", "telemetry.db")
MQTT_HOST = os.environ.get("SKYFEEDER_MQTT_HOST", "10.0.0.4")
MQTT_PORT = int(os.environ.get("SKYFEEDER_MQTT_PORT", "1883"))
MQTT_USER = os.environ.get("SKYFEEDER_MQTT_USER", "")
MQTT_PASS = os.environ.get("SKYFEEDER_MQTT_PASS", "")
MQTT_TOPIC = os.environ.get("SKYFEEDER_MQTT_TOPIC", "skyfeeder/+/telemetry")

conn = sqlite3.connect(DB_PATH, check_same_thread=False)
conn.execute(
    """
    CREATE TABLE IF NOT EXISTS telemetry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts REAL NOT NULL,
        device TEXT NOT NULL,
        payload TEXT NOT NULL,
        weight REAL,
        power_state INTEGER,
        cell_v REAL
    )
    """
)
conn.execute("CREATE INDEX IF NOT EXISTS idx_telemetry_device_ts ON telemetry(device, ts)")
conn.commit()
lock = threading.Lock()

mqtt_client = mqtt.Client()
if MQTT_USER:
    mqtt_client.username_pw_set(MQTT_USER, MQTT_PASS)

app = FastAPI(title="SkyFeeder Telemetry Logger", version="0.1.0")


def _store_sample(device: str, payload: str, weight: float, power_state: int, cell_v: float) -> None:
    with lock:
        conn.execute(
            "INSERT INTO telemetry(ts, device, payload, weight, power_state, cell_v) VALUES (?,?,?,?,?,?)",
            (time.time(), device, payload, weight, power_state, cell_v),
        )
        conn.commit()


def on_connect(client: mqtt.Client, userdata, flags, rc):
    print(f"[mqtt] connected rc={rc}")
    client.subscribe(MQTT_TOPIC, qos=1)


def on_message(client: mqtt.Client, userdata, msg: mqtt.MQTTMessage):
    try:
        payload = msg.payload.decode("utf-8")
        data = json.loads(payload)
    except Exception as exc:
        print(f"[mqtt] decode error: {exc}")
        return
    parts = msg.topic.split("/")
    device = parts[1] if len(parts) > 1 else "unknown"
    weight = float(data.get("weight_g") or data.get("weight", {}).get("g") or 0.0)
    power_state = int(data.get("power", {}).get("state", -1))
    cell_v = float(data.get("power", {}).get("cell_v", 0.0))
    _store_sample(device, payload, weight, power_state, cell_v)


def mqtt_thread():
    while True:
        try:
            mqtt_client.connect(MQTT_HOST, MQTT_PORT, keepalive=30)
            mqtt_client.loop_forever()
        except Exception as exc:
            print(f"[mqtt] connection error: {exc}, retrying in 5s")
            time.sleep(5)


mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message

_thread_started = False
_thread_lock = threading.Lock()


@app.on_event("startup")
def startup_event():
    global _thread_started
    with _thread_lock:
        if not _thread_started:
            t = threading.Thread(target=mqtt_thread, name="mqtt-loop", daemon=True)
            t.start()
            _thread_started = True


@app.get("/", response_class=HTMLResponse)
def index():
    return HTMLResponse(
        """
        <!DOCTYPE html>
        <html><head><title>SkyFeeder Telemetry</title>
        <style>body{font-family:Arial;padding:24px;background:#0b1d2a;color:#fff;}h1{margin-bottom:12px;}table{border-collapse:collapse;width:100%;}td,th{border:1px solid #234;padding:8px;}th{background:#14263a;}</style>
        </head>
        <body>
        <h1>SkyFeeder Telemetry Logger</h1>
        <p>Use <code>/devices</code> to list devices and <code>/chart/&lt;device_id&gt;</code> for JSON suitable for charting.</p>
        </body></html>
        """
    )


@app.get("/devices")
def list_devices():
    with lock:
        rows = conn.execute("SELECT DISTINCT device FROM telemetry ORDER BY device").fetchall()
    return {"devices": [row[0] for row in rows]}


@app.get("/chart/{device_id}")
def chart(device_id: str, limit: int = 60):
    with lock:
        rows: List[Tuple[float, float, float]] = conn.execute(
            "SELECT ts, weight, cell_v FROM telemetry WHERE device=? ORDER BY ts DESC LIMIT ?",
            (device_id, limit),
        ).fetchall()
    rows.reverse()
    labels = [time.strftime("%H:%M:%S", time.localtime(ts)) for ts, *_ in rows]
    weights = [round(weight or 0.0, 2) for _, weight, _ in rows]
    cell_v = [round(v or 0.0, 3) for _, _, v in rows]
    return JSONResponse({"labels": labels, "weight_g": weights, "cell_v": cell_v})


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
