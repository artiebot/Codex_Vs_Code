# SkyFeeder Local Services Stack

This stack replaces all cloud dependencies with local containers (MinIO, presign API, WebSocket relay, OTA file server) so the Option A MVP can run entirely on a LAN without Cloudflare or R2.

## Prerequisites

- Docker Desktop (or Compose v2)
- Node 18+ (only required if you run the services outside of Docker)
- `wscat` (optional, for quick WebSocket testing)

## Quick Start

```bash
cd ops/local
docker compose up -d
```

Services:

| Service       | Port | Description                                         |
|---------------|------|-----------------------------------------------------|
| MinIO         | 9200 | S3-compatible API                                   |
| MinIO Console | 9201 | Web UI                                              |
| presign-api   | 8080 | Presign + discovery + fault injection + day indices |
| ws-relay      | 8081 | Local WebSocket relay (rooms per deviceId)          |
| ota-server    | 9180 | Firmware file host + heartbeat/rollback API         |

Use the default credentials (`minioadmin:minioadmin`) or export `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` before running Compose.

### Environment configuration

`docker-compose.yml` now inlines every presign-api environment variable so the container boots without a local `.env` file. Update the compose file directly (or set overrides in your shell) when you need to tweak endpoints such as `S3_PHOTOS_BASE` or `JWT_SECRET`.

#### Gallery manifest endpoint

The iOS TestFlight build fetches gallery manifests from the presign API instead of talking to MinIO directly.

**iOS App Settings:**
- Base URL: `http://10.0.0.4:8080/gallery`
- Device ID: `dev1` (or any device ID with uploaded photos)

**MinIO Object Layout:**
- Bucket: `photos`
- Photos: `<deviceId>/<timestamp>-<id>.jpg` (e.g., `dev1/2025-10-30T01-56-34-417Z-h50dKV.jpg`)
- Indices: `<deviceId>/indices/day-YYYY-MM-DD.json` (e.g., `dev1/indices/day-2025-10-30.json`)

**Environment Variables** (configured in `docker-compose.yml`):

```yaml
GALLERY_BUCKET=photos          # MinIO bucket name
GALLERY_PREFIX=                # Empty - photos are at root of bucket (dev1/...)
MINIO_ENDPOINT=http://minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
```

**API Endpoints:**

1. **Primary manifest** (new format):
   ```bash
   curl http://10.0.0.4:8080/gallery/dev1/indices/latest.json
   ```
   - Returns the latest day index in gallery manifest format
   - Auto-selects newest `dev1/indices/day-YYYY-MM-DD.json`
   - Response includes presigned photo URLs

2. **Legacy manifest** (fallback):
   ```bash
   curl http://10.0.0.4:8080/gallery/dev1/captures_index.json
   ```
   - Falls back to latest day index if direct file doesn't exist
   - Same format as primary endpoint

3. **Photo proxy** (serves actual photos):
   ```bash
   curl http://10.0.0.4:8080/gallery/dev1/photo/2025-10-30T01-56-34-417Z-h50dKV.jpg
   ```
   - Proxies photo downloads from MinIO
   - Handles authentication internally
   - Avoids presigned URL signature issues

**Response Format:**

```json
{
  "captures": [
    {
      "id": "uuid",
      "title": "2025-10-30T01-56-34-417Z-h50dKV.jpg",
      "capturedAt": "2025-10-30T01:56:34Z",
      "duration": null,
      "fileSizeBytes": 5835,
      "thumbnailURL": "http://10.0.0.4:8080/gallery/dev1/photo/...",
      "assetURL": "http://10.0.0.4:8080/gallery/dev1/photo/...",
      "contentType": "image/jpeg"
    }
  ]
}
```

### MinIO Console

Visit <http://localhost:9201> and log in with your MinIO credentials. You can create additional access keys from the UI if desired, but the presign API uses the root credentials by default for local development.

Buckets are bootstrapped automatically (separate buckets with lifecycle rules: `photos` expires in 30 days, `clips` in 1 day):

```
photos/
+-- <deviceId>/
    +-- ... uploaded thumbnails (.jpg, .png)
    +-- indices/day-YYYY-MM-DD.json

clips/
+-- <deviceId>/
    +-- ... uploaded clips (.mp4)
```
Logs for each service are available via `docker compose logs <service>`.

If the buckets are missing (for example after pruning volumes), re-run the init helper with:

```bash
docker compose up -d minio-init
```

### Troubleshooting

- **presign-api crash loops** – confirm the container picked up the inline credentials by running `docker compose logs presign-api`; missing `S3_*` variables indicate a stale compose file or overrides.
- **Missing buckets or lifecycle rules** – run `docker compose up -d minio-init` to recreate `photos` and `clips` with the 30 d / 1 d expirations.
- **Auth errors during uploads** – ensure the PUT request reuses the `Authorization` header returned alongside the presigned URL; MinIO rejects uploads without the token.

#### iOS Gallery Issues

**Problem: "Network request failed" or timeout**

Check the manifest endpoints are accessible:
```bash
# Should return 200 with JSON
curl -i http://10.0.0.4:8080/gallery/dev1/indices/latest.json

# Should also return 200 with same data (fallback)
curl -i http://10.0.0.4:8080/gallery/dev1/captures_index.json
```

If you get 404 with "No index files", verify:
1. Photos exist in MinIO: `docker exec skyfeeder-minio mc ls local/photos/dev1/ --recursive`
2. Day indices exist: Look for files like `dev1/indices/day-2025-10-30.json`
3. `GALLERY_PREFIX` is empty in docker-compose.yml (not "photos")

**Problem: "The data couldn't be read because it isn't in the correct format"**

This usually means date format issues. Verify the manifest has ISO8601 dates without milliseconds:
```bash
curl http://10.0.0.4:8080/gallery/dev1/indices/latest.json | grep capturedAt
# Should show: "capturedAt": "2025-10-30T01:56:34Z"
# NOT: "capturedAt": "2025-10-30T01:56:34.417Z" (with milliseconds)
```

**Problem: Thumbnails show error icon, "Asset download failed"**

The photo proxy endpoint may not be working. Test directly:
```bash
# Get a photo filename from the manifest
PHOTO=$(curl -s http://10.0.0.4:8080/gallery/dev1/indices/latest.json | grep -o '2025.*\.jpg' | head -1)

# Test the photo proxy
curl -I http://10.0.0.4:8080/gallery/dev1/photo/$PHOTO
# Should return: HTTP/1.1 200 OK with Content-Type: image/jpeg
```

If you get 403 Forbidden, the photo proxy isn't configured correctly. Rebuild:
```bash
docker compose build presign-api
docker compose up -d --force-recreate presign-api
```

**Problem: Wrong device ID**

The iOS app defaults to `field-kit-1`. Change it in Settings to `dev1` (or whatever device ID has photos in MinIO).
