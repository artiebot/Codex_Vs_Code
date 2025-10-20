# Local Stack Examples

## Presign PUT / Upload / Get

```bash
# Request upload slot for JPEG thumbnail
curl -s http://localhost:8080/v1/presign/put \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"dev1","kind":"photos","contentType":"image/jpeg"}' | jq .

# Upload using returned uploadUrl + Authorization header
curl -X PUT "<uploadUrl>" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: image/jpeg" \
  --data-binary @thumb.jpg

# Fetch download URL for saved object
curl "http://localhost:8080/v1/presign/get?deviceId=dev1&kind=photos&objectKey=dev1/<filename>.jpg" | jq .
# objectKey must be relative to the bucket (`photos/dev1/...`), do not prefix with the bucket name.
```

## Discovery Payload

```bash
curl http://localhost:8080/v1/discovery/dev1 | jq .
```

Example response:
```json
{
  "deviceId": "dev1",
  "fw_version": "0.0.0-local",
  "video": {
    "thumb_base": "http://localhost:9200/photos/dev1/",
    "clip_base": "http://localhost:9200/clips/dev1/",
    "retention": { "clips_days": 1, "photos_days": 30 }
  },
  "signal_ws": "ws://localhost:8081",
  "presign_base": "http://localhost:8080/v1/presign",
  "ota_base": "http://localhost:9180",
  "step": "A1.1-local",
  "cap": ["upload_immediate","ram_retry_queue","save_to_photos"],
  "services": ["weight","motion","visit","camera","ota","logs"]
}
```

## WebSocket Messaging

Generate device token:
```bash
TOKEN=$(node -e "console.log(require('jsonwebtoken').sign({deviceId:'dev1'}, 'dev-only'))")
wscat -c "ws://localhost:8081?token=$TOKEN"
```

Send ping:
```
> {"type":"ping"}
< {"type":"pong","ts":1697136000000}
```

Send upload-status event:
```
> {"type":"event.upload_status","payload":{"status":"retrying","attempt":2,"nextRetryInSec":60}}
< {"type":"event.upload_status","payload":{"status":"retrying","attempt":2,"nextRetryInSec":60},"deviceId":"dev1","ts":1697136005000}
```

Metrics:
```bash
curl http://localhost:8081/v1/metrics | jq .
```

## Fault Injection

```bash
../../scripts/dev/faults.sh dev1 --rate 0.4 --code 503 --minutes 2 --api http://localhost:8080
```

## OTA Heartbeat

```bash
curl -X POST http://localhost:9180/v1/ota/heartbeat \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"dev1","version":"1.2.3","slot":"B","bootCount":1,"status":"boot"}' | jq .
```

Status dashboard:
```bash
curl http://localhost:9180/v1/ota/status | jq .
```

## Day Index Files

Objects are appended to `indices/<deviceId>/day-YYYY-MM-DD.json`:
```json
{
  "deviceId": "dev1",
  "date": "2025-10-12",
  "generatedTs": 1697130000000,
  "updatedTs": 1697133600000,
  "events": [
    {
      "id": "abc123xy",
      "ts": 1697133600000,
      "key": "dev1/2025-10-12T17-00-00-123456.jpg",
      "kind": "photos",
      "bytes": 98234,
      "sha256": "..."
    }
  ]
}
```
