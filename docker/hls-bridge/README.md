# HLS Bridge (Phase A1.1)

This Docker-based tool converts the AMB82 Mini’s RTSP stream into an HTTP HLS feed
that the mobile app (and other clients) can consume. The stack has two containers:

| Service  | Role | Notes |
|----------|------|-------|
| `ffmpeg` | Pulls RTSP, generates rolling HLS segments (`*.ts`) and playlist (`*.m3u8`). | Uses `jrottenberg/ffmpeg`, copies the camera’s H.264 stream without re-encoding. Restarts automatically on errors. |
| `nginx`  | Serves the HLS outputs over HTTP. | Exposes port `8080` (configurable); enables CORS and a `/healthz` endpoint for monitoring. |

All generated files live under `docker/hls-bridge/output/` so they are easy to inspect
and attach to validation reports.

---

## Quick Start

1. **Prerequisites**
   - Docker Desktop (or compatible runtime) installed and running.
   - `docker compose` available on your PATH.
   - The Mini online and reachable via RTSP (e.g. `rtsp://10.0.0.198/live`).

2. **Configure environment**
   ```powershell
   cd docker/hls-bridge
   Copy-Item .env.example .env       # edit RTSP_URL, port, etc.
   ```

3. **Start the bridge**
   ```powershell
   docker compose up -d
   ```

   The first run creates `output/` with live `mini.m3u8` and segment files.

4. **Validate**
   - Playlist: <http://localhost:8080/hls/mini.m3u8>
   - Inspect segments: `docker compose logs ffmpeg`
   - Health check: `curl http://localhost:8080/healthz`

5. **Stop**
   ```powershell
   docker compose down
   ```

---

## Useful Commands

```powershell
# Tail FFmpeg logs (watch reconnects, errors, etc.)
docker compose logs -f ffmpeg

# Show container status
docker compose ps

# Rotate output files without restarting containers
Remove-Item output\* -Include *.ts,*.m3u8
```

The FFmpeg entrypoint automatically restarts the pull if the Mini drops off the
network. Review the log output when capturing artifacts for `validation_A1.1.txt`.

---

## Environment Variables

All variables can be set in `.env` (or via the shell) before calling `docker compose`.

| Variable | Default | Description |
|----------|---------|-------------|
| `RTSP_URL` | `rtsp://10.0.0.198/live` | Mini RTSP endpoint. |
| `HLS_HTTP_PORT` | `8080` | Host port that serves the HLS playlist and segments. |
| `HLS_STREAM_NAME` | `mini` | Base filename for playlist and segments. |
| `HLS_SEGMENT_SECONDS` | `2` | HLS segment duration in seconds. |
| `HLS_WINDOW` | `6` | Number of segments to keep in the live playlist. |

Adjust `HLS_SEGMENT_SECONDS`/`HLS_WINDOW` if you need longer playback buffers.

---

## Troubleshooting

- **Playlist 404:** Confirm FFmpeg is writing files (`docker compose logs ffmpeg`) and that the Mini is awake.
- **Stale frames after wake:** Delete `output/*.ts` and `output/*.m3u8` before restarting the bridge.
- **Docker permission errors on Windows:** If `output/` has read-only flags (OneDrive), clear them with `attrib -R output`.
- **Low latency vs stability:** If you see frequent reconnects, increase `HLS_SEGMENT_SECONDS` to 3–4 seconds to ease network jitter.

Report issues and capture relevant logs in `REPORTS/validation_A1.1.txt`.
