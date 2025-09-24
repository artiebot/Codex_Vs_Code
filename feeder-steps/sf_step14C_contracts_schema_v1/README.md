# 14C - Contracts Schema v1

## Overview
Defines the JSON Schema contract for every MQTT topic (`discovery`, `status`, `telemetry`, `cmd`, `ack`) so firmware and app developers can build in parallel against a shared `v1` specification. Example payloads demonstrate the shape and required fields, and a lightweight Node validator keeps the schemas honest.

## Files changed / created
- `contracts/schema-v1/discovery.schema.json`
- `contracts/schema-v1/status.schema.json`
- `contracts/schema-v1/telemetry.schema.json`
- `contracts/schema-v1/cmd.schema.json`
- `contracts/schema-v1/ack.schema.json`
- `contracts/examples/discovery.dev3.json`
- `contracts/examples/status.online.json`
- `contracts/examples/telemetry.sample.json`
- `contracts/examples/cmd.led.heartbeat.json`
- `contracts/examples/ack.ok.json`
- `contracts/tools/validate.js`
- `STEPS.md`

## Topics & QoS
- `skyfeeder/<id>/discovery` - retained, QoS 1, includes `"schema": "v1"` for compatibility.
- `skyfeeder/<id>/status` - publish `online` on connect, set LWT to `offline`; QoS 1 so app reliably receives state transitions.
- `skyfeeder/<id>/telemetry` - periodic/events data; QoS 0 acceptable for speed but supports QoS 1 when needed (see schema `qos.telemetry`).
- `skyfeeder/<id>/cmd/#` - app-issued commands; QoS 1 recommended for reliability.
- `skyfeeder/<id>/ack` - device acknowledgements for commands; QoS 1 to guarantee delivery back to the app.

## Command & ACK envelopes
- All commands wrap payloads as `{ "schema": "v1", "reqId", "type", "payload" }`.
- `reqId` must be unique per in-flight command (4-64 chars, `A-Za-z0-9_-`) so acknowledgements can match responses.
- Supported command types:
  - `type: "led"` with `payload.pattern` in `{ "heartbeat", "off", "blink" }`.
  - `type: "camera"` with `payload.action` = `"snap"`.
- ACK payload `{ "schema": "v1", "reqId", "ok", "code", "msg", "data?", "ts?" }` mirrors the command `reqId` and lets the device return contextual data (`data.pattern`, capture metadata, etc.).

## How to run / validate
```bash
cd contracts
npm i ajv ajv-formats
node tools/validate.js schema-v1/discovery.schema.json examples/discovery.dev3.json
node tools/validate.js \
  schema-v1/status.schema.json examples/status.online.json \
  schema-v1/telemetry.schema.json examples/telemetry.sample.json \
  schema-v1/cmd.schema.json examples/cmd.led.heartbeat.json \
  schema-v1/ack.schema.json examples/ack.ok.json
```

## Success criteria checklist
- [ ] All examples validate against their schemas
- [ ] Topics & QoS documented
- [ ] Command/ACK envelopes documented with `reqId` rules

## Troubleshooting
- **Schema error before validation** - AJV will print `Schema error` lines; fix malformed JSON or missing `$id`/`$schema` keys.
- **`instancePath` empty (`/`)** - Root object failed; check required top-level fields and typos in `schema`, `reqId`, etc.
- **Format-related failures** - Install `ajv-formats` (per the command above) so IPv4, date-time, and MAC formats pass.

## Next step
Continue with [14D Backend Staging & Mock Publisher](../sf_step14D_backend_staging_mock_publisher/README.md).
