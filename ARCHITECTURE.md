# SkyFeeder Architecture (Phase A Baseline)

## Control Plane
- **Single MQTT endpoint on ESP32.**  
  The ESP32 owns all MQTT connections (commands, telemetry, events). Devices and apps interact with the broker only through topics hosted by the ESP32 firmware.
- **AMB Mini over UART.**  
  The Realtek AMB82 Mini no longer maintains an MQTT session. Control and status exchange flow over a newline-delimited JSON protocol on UART (ESP32 Serial2). The ESP32 translates `cmd/cam` MQTT messages into UART operations (`wake`, `sleep`, `snapshot`, Wi-Fi staging) and relays Mini status, snapshot metadata, and test results back to MQTT.
- **Acknowledgements & metadata.**  
  MQTT acknowledgements and snapshot metadata are published from the ESP32 (`skyfeeder/<id>/event/ack`, `skyfeeder/<id>/event/snapshot`). The Mini never publishes to MQTT directly.

## Video Plane
- **RTSP on AMB Mini.**  
  The Mini continues to serve its native RTSP stream (`rtsp://<mini-ip>/live`) and keeps the `/snapshot.jpg` HTTP endpoint for still captures.
- **RTSP -> HLS bridge.**  
  Phase A1.1 adds a Dockerised FFmpeg/Nginx bridge (docker/hls-bridge) that converts the Mini’s RTSP stream to HLS. Future app clients consume HLS, while the ESP32 continues to transport only metadata.

## Metadata Flow
1. App sends MQTT command (`cmd/cam`) -> ESP32.
2. ESP32 sends UART JSON -> Mini.
3. Mini executes (wake/sleep/snapshot) and replies with UART JSON status.
4. ESP32 publishes MQTT acknowledgement (`event/ack`) and, for snapshots, metadata (`event/snapshot`, URL placeholder until HLS is live).

This document supersedes earlier notes that described the Mini as an MQTT client. Any legacy references should be considered deprecated.***
