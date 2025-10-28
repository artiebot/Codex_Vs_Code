# MQTT De-scope Audit Summary

## Executive summary
- The local developer stack (`ops/local/docker-compose.yml`) provisions only MinIO, minio-init, presign-api, ws-relay, and ota-server. No MQTT brokers (Mosquitto, EMQX, HiveMQ) or ports 1883/8883 are defined, confirming that HTTP/S3/WebSocket are the only active pathways for A1.x/B-series validation.
- MQTT references remain only in legacy or optional assets—Expo prototype code, historical feeder-step documentation, archived QA reports, PowerShell tooling, and `mosquitto_websocket.conf`. These artifacts are non-blocking for validation but should be labelled for future cleanup.

## Findings table
| Area | File / Location | Evidence | Impact | Action needed? | Suggested owner |
|------|-----------------|----------|--------|----------------|-----------------|
| Infra | `ops/local/docker-compose.yml` | Services: `minio`, `presign-api`, `ws-relay`, `ota-server`, `minio-init`; no 1883/8883 ports. | Confirms runtime is MQTT-free. | No | DevOps |
| Infra | `mosquitto_websocket.conf` | Legacy config enabling anonymous MQTT on 1883/9001. | Inactive but could confuse readers. | No | Documentation |
| Code (mobile) | `app/skyfeeder-app/` | Expo dashboard imports `mqtt` and constructs MQTT clients for archived Step 14 flows. | Legacy prototype only; not used in validation. | No | Mobile/UI |
| Docs | `feeder-steps/**/README.md` | Instructions reference Mosquitto topics. | Historical training materials. | No | Documentation |
| Tooling | `tools/mqtt-*.ps1` | Scripts publish MQTT commands using Mosquitto CLI. | Optional helpers; unused in validation path. | No | Ops Tooling |
| QA Archives | `REPORTS/**` | QA notes mention Mosquitto commands. | Archival evidence only. | No | QA |
| Sample data | `latest.json` | Field `mqtt_retries` retained as metadata. | Does not reintroduce MQTT dependency. | No | Firmware Telemetry |

## Runtime checks
Docker/ss/lsof are unavailable in this environment, but the compose specification above enumerates all services; none bind port 1883 or 8883.

```
$ docker compose config --services
bash: docker: command not found

$ ss -tulpn | grep -E ':1883|:8883'
bash: ss: command not found

$ lsof -i :1883
bash: lsof: command not found
```

## Conclusion
MQTT is fully removed from the active stack; remaining mentions live in optional or archived assets and pose no risk to the current validation path. No changes were made as part of this audit. Future cleanup can safely archive or delete the legacy materials when convenient.
