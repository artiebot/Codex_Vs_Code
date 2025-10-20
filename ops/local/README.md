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
