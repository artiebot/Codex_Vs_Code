# SkyFeeder Step 15 ? App Logging (MQTT ? SQLite)

## Delta vs Step 14
- Added `server/mqtt_subscriber.py` (FastAPI + paho-mqtt) that stores telemetry into `telemetry.db`
- Minimal `/devices` + `/chart/<device>` endpoints for quick charts; static HTML hint at `/`
- Firmware unchanged from Step 14 (continues to use provisioning/discovery stack)

## Library Dependencies
- Device: unchanged (ESP32 core libs, ArduinoJson, PubSubClient, esp_camera, HX711, Adafruit NeoPixel)
- Server: FastAPI, Uvicorn, paho-mqtt, SQLite (stdlib)

## Build & Flash (device)
1. Open `sf_step15_logging/sf_step15_logging.ino`
2. Board: `ESP32 Dev Module`
3. Upload and provision as in Step 14 if not already configured

## Run the Logging Service
1. Create virtualenv & install deps:
   ```bash
   cd server
   python -m venv .venv
   . .venv/bin/activate  # or .venv\Scripts\activate on Windows
   pip install -r requirements.txt
   ```
2. Export MQTT credentials if they differ from defaults:
   ```bash
   export SKYFEEDER_MQTT_HOST=10.0.0.4
   export SKYFEEDER_MQTT_USER=dev1
   export SKYFEEDER_MQTT_PASS=dev1pass
   ```
3. Start the app:
   ```bash
   uvicorn mqtt_subscriber:app --reload --host 0.0.0.0 --port 8080
   ```
4. Browse to `http://localhost:8080/devices` (lists provisioned devices) and `http://localhost:8080/chart/<device_id>` for JSON ready to feed a chart. A simple HTML stub is available at `/`.

## Success Criteria
1. Device publishes telemetry normally (verify via `skyfeeder/<id>/telemetry`)
2. Run logging service; verify console shows `[mqtt] connected` and rows appear in SQLite (`sqlite3 telemetry.db 'SELECT COUNT(*) FROM telemetry;'`)
3. Fetch `http://localhost:8080/chart/<device_id>?limit=20` and confirm weight + cell voltage arrays populate
4. Load data into a browser chart (copy JSON into a quick Chart.js playground) to visualise feeder weight trend

## Troubleshooting
- **No rows recorded**: ensure logging script has network access to MQTT broker and credentials match provisioning
- **`sqlite3.OperationalError: database is locked`**: script should serialise writes, but if you manually inspect DB while script runs use `sqlite3` in WAL-friendly `PRAGMA journal_mode=WAL` mode
- **MQTT connection refused**: confirm broker allows additional clients; adjust `SKYFEEDER_MQTT_*` environment variables as needed
