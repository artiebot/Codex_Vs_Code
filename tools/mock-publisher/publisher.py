#!/usr/bin/env python3
"""SkyFeeder mock publisher for staging/app validation.

Publishes retained discovery + status messages, periodic telemetry,
and responds to command topics with ACK payloads so the app can
exercise end-to-end control flows. Optionally advertises 15A logging
capability so backend/app teammates can validate without flashing
firmware.
"""
from __future__ import annotations

import argparse
import binascii
import json
import math
import random
import signal
import sys
import threading
import time
from collections import deque
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional, Tuple

import paho.mqtt.client as mqtt

DEFAULT_HOST = "10.0.0.4"
DEFAULT_PORT = 1883
DEFAULT_USERNAME = "dev1"
DEFAULT_PASSWORD = "dev1pass"
DEFAULT_DEVICE_ID = "sf-mock01"
DEFAULT_INTERVAL = 15  # seconds
DEFAULT_SERVICES: Tuple[str, ...] = ("power", "weight", "motion", "led", "camera", "ota")
LOG_CAPACITY = 64
LOG_MAX_LEN = 96

running = True


def utc_now() -> str:
    """Return current UTC time in ISO-8601 format."""
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()

def pseudo_ota_byte(index: int) -> int:
    """Match firmware stub byte generator for deterministic CRC."""
    return (((index * 29) + 0x5F) ^ 0xA5) & 0xFF


class LogBuffer:
    def __init__(self, capacity: int = LOG_CAPACITY, max_len: int = LOG_MAX_LEN) -> None:
        self._buffer: deque[Dict[str, Any]] = deque(maxlen=capacity)
        self._max_len = max_len
        self._lock = threading.Lock()
        self._device_id = "sf-mock"

    def set_device(self, device_id: str) -> None:
        self._device_id = device_id or "sf-mock"

    def boot_marker(self, reason: str = "mock_start") -> None:
        self.append("boot", "boot", f"boot_reason={reason}")

    def append(self, level: str, tag: str, message: str) -> None:
        entry = {
            "ts": utc_now(),
            "level": level,
            "tag": (tag or "log")[: 12],
            "msg": (message or "")[: self._max_len],
        }
        with self._lock:
            self._buffer.append(entry)

    def dump(self, clear: bool = False) -> Dict[str, Any]:
        with self._lock:
            entries = list(self._buffer)
            if clear:
                self._buffer.clear()
        return {"device": self._device_id, "count": len(entries), "entries": entries}


log_buffer = LogBuffer()


def build_topics(device_id: str, include_logs: bool) -> Dict[str, str]:
    base = f"skyfeeder/{device_id}"
    topics = {
        "discovery": f"{base}/discovery",
        "status": f"{base}/status",
        "telemetry": f"{base}/telemetry",
        "cmd": f"{base}/cmd",
        "ack": f"{base}/ack",
        "cmd_ota": f"{base}/cmd/ota",
        "event_ota": f"{base}/event/ota",
    }
    if include_logs:
        topics["cmd_logs"] = f"{base}/cmd/logs"
        topics["event_log"] = f"{base}/event/log"
    return topics


def discovery_payload(device_id: str, services: Iterable[str], topics: Dict[str, str], include_logs: bool) -> Dict[str, Any]:
    caps = list(dict.fromkeys(list(DEFAULT_SERVICES) + list(services)))
    if include_logs and "logs" not in caps:
        caps.append("logs")
    payload_topics = {
        "discovery": topics["discovery"],
        "status": topics["status"],
        "telemetry": topics["telemetry"],
        "cmd": topics["cmd"],
        "ack": topics["ack"],
        "cmd_ota": topics["cmd_ota"],
        "event_ota": topics["event_ota"],
    }
    if include_logs:
        payload_topics["cmd_logs"] = topics["cmd_logs"]
        payload_topics["event_log"] = topics["event_log"]
    return {
        "schema": "v1",
        "id": device_id,
        "fw": "skyfeeder-esp32-1.4.0",
        "hw": "revC",
        "mac": "24:6F:28:FA:1C:01",
        "ip": "10.0.0.231",
        "capabilities": caps,
        "topics": payload_topics,
        "qos": {
            "discovery": 1,
            "status": 1,
            "telemetry": 0,
            "cmd": 1,
            "ack": 1,
            "cmd_ota": 1,
            "event_ota": 0,
            **({"cmd_logs": 1, "event_log": 0} if include_logs else {}),
        },
        "ts": utc_now(),
        "notes": "Mock device published by tools/mock-publisher",
    }


def status_payload(state: str, reason: str | None = None) -> Dict[str, Any]:
    payload: Dict[str, Any] = {
        "schema": "v1",
        "ts": utc_now(),
        "state": state,
        "fw": "skyfeeder-esp32-1.4.0",
    }
    if reason:
        payload["reason"] = reason
    return payload


def telemetry_payload(base_weight: float, rssi: int, seq: int) -> Dict[str, Any]:
    weight = base_weight + math.sin(seq / 3.5) * 4.0 + random.uniform(-0.6, 0.6)
    soc = max(12.0, min(100.0, 76.0 - seq * 0.05 + random.uniform(-0.3, 0.3)))
    watts = 3.2 + math.sin(seq / 4.0) * 0.6
    amps = 0.28 + math.sin(seq / 5.0) * 0.04
    volts = watts / amps if amps else 12.0
    reported_rssi = max(-120, min(0, rssi + random.randint(-2, 2)))
    payload = {
        "schema": "v1",
        "ts": utc_now(),
        "rssi": reported_rssi,
        "uptime_s": int(time.monotonic()),
        "power": {
            "volts": round(volts, 2),
            "amps": round(amps, 3),
            "watts": round(watts, 2),
            "soc_pct": round(soc, 1),
        },
        "weight_g": round(weight, 2),
        "motion": random.random() < 0.05,
        "temperature_c": round(24.0 + math.sin(seq / 6.0) * 0.8, 1),
    }
    payload["health"] = {
        "uptime_ms": int(time.monotonic() * 1000),
        "last_seen_ms": int(time.time() * 1000),
        "telemetry_count": seq + 1,
        "mqtt_retries": 0,
        "rssi": reported_rssi,
    }
    return payload


def publish_json(client: mqtt.Client, topic: str, payload: Dict[str, Any], *, retain: bool, wait: bool = False) -> None:
    data = json.dumps(payload, separators=(",", ":"))
    result = client.publish(topic, data, qos=1 if retain else 0, retain=retain)
    if wait:
        result.wait_for_publish()
    if result.rc != mqtt.MQTT_ERR_SUCCESS:
        raise RuntimeError(f"Publish to {topic} failed: {mqtt.error_string(result.rc)}")


def publish_ack(client: mqtt.Client, topic: str, payload: Dict[str, Any]) -> None:
    data = json.dumps(payload, separators=(",", ":"))
    result = client.publish(topic, data, qos=1, retain=False)
    if result.rc != mqtt.MQTT_ERR_SUCCESS:
        raise RuntimeError(f"Publish to {topic} failed: {mqtt.error_string(result.rc)}")
    print(f"ACK publish queued (mid={result.mid})")


def decode_json_payload(payload: bytes) -> Dict[str, Any]:
    raw = payload.decode("utf-8", errors="replace")
    raw = raw.lstrip("\ufeff")
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"JSON parse error: {exc}") from exc


def normalize_ota_payload(data: Dict[str, Any]) -> Tuple[Optional[str], Optional[str], int, int]:
    if not isinstance(data, dict):
        raise ValueError("JSON object expected")
    ota = data.get("ota")
    payload = ota if isinstance(ota, dict) else data

    req_id = data.get("reqId") or payload.get("reqId")
    url = payload.get("url") or payload.get("image")

    raw_size = payload.get("size") or payload.get("sizeBytes")
    try:
        size = int(raw_size)
    except (TypeError, ValueError):
        raise ValueError("missing or invalid size")
    if size <= 0:
        raise ValueError("missing or invalid size")

    chunk = payload.get("chunkBytes")
    try:
        chunk_bytes = int(chunk) if chunk is not None else 0
    except (TypeError, ValueError):
        raise ValueError("invalid chunkBytes")

    return req_id, url, size, chunk_bytes


def publish_ota_event(
    client: mqtt.Client,
    topics: Dict[str, str],
    status: str,
    *,
    req_id: Optional[str] = None,
    size: Optional[int] = None,
    progress: Optional[int] = None,
    crc: Optional[str] = None,
    reason: Optional[str] = None,
    detail: Optional[str] = None,
    url: Optional[str] = None,
    message: Optional[str] = None,
    dry_run: bool = False,
) -> None:
    payload: Dict[str, Any] = {"schema": "v1", "status": status}
    if req_id:
        payload["reqId"] = req_id
    if size is not None and size > 0:
        payload["size"] = size
    if progress is not None:
        payload["progress"] = progress
    if crc:
        payload["crc"] = crc
    if reason:
        payload["reason"] = reason
    if detail:
        payload["detail"] = detail
    if url:
        payload["url"] = url
    if message:
        payload["msg"] = message

    if dry_run:
        print(f"[dry-run] OTA event -> {json.dumps(payload)}")
    else:
        publish_json(client, topics["event_ota"], payload, retain=False)


def handle_ota_command_with_payload(
    client: mqtt.Client,
    topics: Dict[str, str],
    payload_bytes: bytes,
    *,
    dry_run: bool,
) -> None:
    try:
        data = decode_json_payload(payload_bytes)
    except ValueError as exc:
        publish_ota_event(
            client,
            topics,
            "error",
            reason="invalid payload",
            detail=str(exc),
            dry_run=dry_run,
        )
        log_buffer.append("warn", "ota", f"parse error: {exc}")
        return

    try:
        req_id, url, size, chunk = normalize_ota_payload(data)
    except ValueError as exc:
        publish_ota_event(
            client,
            topics,
            "error",
            req_id=data.get("reqId") if isinstance(data, dict) else None,
            reason="invalid payload",
            detail=str(exc),
            dry_run=dry_run,
        )
        log_buffer.append("warn", "ota", f"reject {exc}")
        return

    if not req_id:
        req_id = f"req-{int(time.time())}"

    chunk_bytes = max(64, min(chunk if chunk > 0 else 1024, 8 * 1024))

    publish_ota_event(
        client,
        topics,
        "started",
        req_id=req_id,
        size=size,
        progress=0,
        url=url,
        message="OTA command accepted",
        dry_run=dry_run,
    )

    progress_marks = [25, 50, 75]
    thresholds = []
    for mark in progress_marks:
        threshold = (size * mark) // 100
        if threshold == 0:
            threshold = 1
        thresholds.append(threshold)

    processed = 0
    mark_index = 0
    crc = 0
    while processed < size:
        step = min(chunk_bytes, size - processed)
        block = bytearray(pseudo_ota_byte(processed + i) for i in range(step))
        crc = binascii.crc32(block, crc)
        processed += step
        while mark_index < len(progress_marks) and processed >= thresholds[mark_index]:
            time.sleep(0.05)
            publish_ota_event(
                client,
                topics,
                "progress",
                req_id=req_id,
                size=size,
                progress=progress_marks[mark_index],
                url=url,
                dry_run=dry_run,
            )
            mark_index += 1

    time.sleep(0.05)
    crc &= 0xFFFFFFFF
    publish_ota_event(
        client,
        topics,
        "verified",
        req_id=req_id,
        size=size,
        progress=100,
        crc=f"{crc:08X}",
        url=url,
        message="CRC verified",
        dry_run=dry_run,
    )
    log_buffer.append("info", "ota", f"size={size} crc={crc:08X}")


def respond_to_command(
    client: mqtt.Client,
    topics: Dict[str, str],
    topic: str,
    payload: bytes,
    *,
    dry_run: bool,
) -> None:
    try:
        command = decode_json_payload(payload)
    except ValueError as err:
        print(f"Invalid command payload: {err}", file=sys.stderr)
        return

    if not isinstance(command, dict):
        print("Unsupported command format (expected object)", file=sys.stderr)
        return

    req_id = command.get("reqId") or f"req-{int(time.time())}"
    cmd_type = command.get("type")
    ack_topic = topics["ack"]

    ack: Dict[str, Any] = {
        "schema": "v1",
        "reqId": req_id,
        "ts": utc_now(),
        "ok": True,
        "code": "cmd.accepted",
        "msg": "Command accepted",
    }

    if cmd_type == "led":
        pattern = command.get("payload", {}).get("pattern")
        if pattern in {"heartbeat", "blink", "off"}:
            ack["code"] = f"led.{pattern}"
            ack["msg"] = f"LED pattern set to {pattern}"
            ack["data"] = {"pattern": pattern}
        else:
            ack["ok"] = False
            ack["code"] = "led.invalid_pattern"
            ack["msg"] = f"Unsupported LED pattern: {pattern}"
    elif cmd_type == "camera":
        ack["code"] = "camera.snap"
        ack["msg"] = "Camera snapshot scheduled"
        ack["data"] = {"action": "snap"}
    else:
        ack["ok"] = False
        ack["code"] = "cmd.unsupported"
        ack["msg"] = f"Unsupported command type: {cmd_type}"

    log_buffer.append("info", "cmd", f"cmd={cmd_type} req={req_id} ok={ack.get('ok')}")

    if dry_run:
        print(f"[dry-run] Would ACK {cmd_type}: {json.dumps(ack)}")
        return

    publish_ack(client, ack_topic, ack)
    print(f"ACK sent for {cmd_type} ({req_id}) -> {ack_topic}")


def mqtt_connect(args: argparse.Namespace, topics: Dict[str, str], include_logs: bool) -> mqtt.Client:
    # Use older API for compatibility
    client = mqtt.Client(client_id=f"skyfeeder-mock-{args.device_id}", clean_session=True)
    client.username_pw_set(args.username, args.password)

    offline_status = status_payload("offline", reason="lost connection")
    client.will_set(
        topics["status"],
        json.dumps(offline_status, separators=(",", ":")),
        qos=1,
        retain=True,
    )

    def handle_connect(_client: mqtt.Client, _userdata: Any, _flags: Dict[str, Any], rc: int) -> None:
        print(f"[mqtt] connected rc={rc}")
        if rc != 0:
            print(f"MQTT connect failed: {mqtt.connack_string(rc)}", file=sys.stderr)
            return
        subs = [
            (topics["cmd"], 1),
            (f"{topics['cmd']}/#", 1),
            (topics["cmd_ota"], 1),
        ]
        if include_logs and "cmd_logs" in topics:
            subs.append((topics["cmd_logs"], 1))
        for sub_topic, qos in subs:
            result, mid = _client.subscribe(sub_topic, qos=qos)
            print(f"[mqtt] subscribe {sub_topic} qos={qos} -> {result}/{mid}")

    def handle_disconnect(_client: mqtt.Client, _userdata: Any, rc: int) -> None:
        print(f"[mqtt] disconnected rc={rc}")

    client.on_connect = handle_connect
    client.on_disconnect = handle_disconnect

    if args.dry_run:
        return client

    client.loop_start()
    client.connect(args.host, args.port, keepalive=30)

    wait_start = time.time()
    while not client.is_connected():
        if time.time() - wait_start > 5:
            break
        time.sleep(0.1)

    return client


def stop_loop(*_sig: Any) -> None:
    global running
    running = False


def build_services(args: argparse.Namespace) -> Tuple[List[str], bool]:
    parsed: List[str] = []
    if args.services:
        parsed = [s.strip().lower() for s in args.services.split(",") if s.strip()]
    include_logs = args.enable_logs or not parsed or "logs" in parsed
    if include_logs and "logs" not in parsed:
        parsed.append("logs")
    return parsed, include_logs


def handle_log_command(client: mqtt.Client, topic: str, payload: bytes) -> None:
    clear = False
    if payload:
        try:
            body = decode_json_payload(payload)
            clear = bool(body.get("clear", False))
        except ValueError:
            print("Invalid log command payload; assuming clear=false")
    response = log_buffer.dump(clear=clear)
    event_topic = topic.replace("cmd/logs", "event/log")
    client.publish(event_topic, json.dumps(response), qos=0, retain=False)
    print(f"Log dump published ({response['count']} entries) -> {event_topic}")


def run(args: argparse.Namespace) -> None:
    services, include_logs = build_services(args)
    topics = build_topics(args.device_id, include_logs)
    log_buffer.set_device(args.device_id)
    if include_logs:
        log_buffer.boot_marker()
    client = mqtt_connect(args, topics, include_logs)

    if not args.dry_run:
        def on_message(_client: mqtt.Client, _userdata: Any, message: mqtt.MQTTMessage) -> None:
            print(f"[mqtt] RX {message.topic} ({len(message.payload)} bytes)")
            if include_logs and message.topic == topics.get("cmd_logs"):
                return
            if message.topic == topics.get("cmd_ota"):
                handle_ota_command_with_payload(client, topics, message.payload, dry_run=args.dry_run)
                return
            if message.topic.startswith(topics["cmd"]):
                respond_to_command(client, topics, message.topic, message.payload, dry_run=args.dry_run)

        client.on_message = on_message
        if include_logs and "cmd_logs" in topics:
            client.message_callback_add(
                topics["cmd_logs"],
                lambda _client, _userdata, msg: handle_log_command(client, msg.topic, msg.payload),
            )
        print(f"Listening for commands on {topics['cmd']}/#")

    try:
        discovery = discovery_payload(args.device_id, services, topics, include_logs)
        status_online = status_payload("online")

        if args.dry_run:
            print("[dry-run] Would publish discovery", json.dumps(discovery, indent=2))
            print("[dry-run] Would publish status", json.dumps(status_online, indent=2))
        else:
            publish_json(client, topics["discovery"], discovery, retain=True, wait=True)
            publish_json(client, topics["status"], status_online, retain=True, wait=True)
            log_buffer.append("info", "status", "status=online")
            print(f"Published retained discovery + status for {args.device_id}")

        tick = 0
        base_weight = args.base_weight
        while running:
            payload = telemetry_payload(base_weight, args.rssi, tick)
            if args.dry_run:
                print("[dry-run] Would publish telemetry", json.dumps(payload, indent=2))
            else:
                publish_json(client, topics["telemetry"], payload, retain=False)
                if tick % 4 == 0:
                    log_buffer.append("info", "telemetry", f"power={payload['power']['watts']}W weight={payload['weight_g']}g")
                print(f"Telemetry {tick + 1} sent -> {topics['telemetry']}")
            tick += 1
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("Interrupted by user")
    finally:
        if not args.dry_run:
            publish_json(client, topics["status"], status_payload("offline", "mock stopped"), retain=True)
            client.loop_stop()
            client.disconnect()
            print("Disconnected")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=DEFAULT_HOST, help="MQTT broker host")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="MQTT broker port")
    parser.add_argument("--username", default=DEFAULT_USERNAME, help="MQTT username")
    parser.add_argument("--password", default=DEFAULT_PASSWORD, help="MQTT password")
    parser.add_argument("--device-id", default=DEFAULT_DEVICE_ID, help="Device ID for topic names")
    parser.add_argument("--interval", type=int, default=DEFAULT_INTERVAL, help="Seconds between telemetry publishes")
    parser.add_argument("--base-weight", type=float, default=1234.0, help="Base weight in grams for telemetry")
    parser.add_argument("--rssi", type=int, default=-62, help="RSSI value to report")
    parser.add_argument("--services", default=None, help="Comma-separated services to advertise (e.g. logs,telemetry)")
    parser.add_argument("--enable-logs", action="store_true", help="Ensure logging service is advertised")
    parser.add_argument("--dry-run", action="store_true", help="Print payloads instead of publishing")
    return parser.parse_args()


def main() -> None:
    signal.signal(signal.SIGINT, stop_loop)
    signal.signal(signal.SIGTERM, stop_loop)
    args = parse_args()
    try:
        run(args)
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()