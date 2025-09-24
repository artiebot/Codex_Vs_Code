# 15A - Logging & Diagnostics

## Overview
Implements a device-side ring buffer logger with boot/crash markers and an MQTT dump service. Logs are retained in RAM with configurable depth, can be cleared on demand, and are exposed over the new `cmd/logs` and `event/log` topics so backend tooling can fetch recent history during triage. Configuration and provisioning now advertise the logging capability in discovery messages.

## Files changed / created
- `logging.h`, `logging.cpp` - ring buffer implementation, boot/crash capture, JSON dump helper.
- `log_service.h`, `log_service.cpp` - MQTT handler for `cmd/logs` → `event/log` responses.
- `topics.h`, `topics.cpp` - topic helpers refreshed with log-specific endpoints.
- `provisioning.cpp` - boot marker call, logging discovery fields.
- `config.h` - logging tunables.
- `tools/mock-publisher/publisher.py` - mock broker logging emulation for validation.
- `tools/mock-publisher/tests/test_logs.py` - host-side log command smoke test.
- `CHANGELOG.md` - entry for this step.
- `feeder-steps/15A_logging/README.md` (this file).

## Config
```
LOG_RING_CAPACITY = 64   // Max buffered entries.
LOG_ENTRY_MAX_LEN = 96   // Max chars per entry (post-format).
```
Tweak the macros in `config.h` or override at compile time.

## How to integrate on firmware
1. Call `SF::Log::init()` early in `setup()`.
2. After MQTT connects, subscribe to log commands: `SF::LogService::begin(client);`.
3. Forward MQTT callbacks to `SF::LogService::handleMessage()` when topic equals `Topics::cmdLogs()`.
4. Use `SF::Log::info("tag", "message")` et al. throughout services.

`Topics::init(deviceId)` wires the logger with the device identifier used in dumps.

## Validation (mock publisher)
Use the updated mock publisher to validate 15A without flashing firmware:

### 1. Start the mock
```powershell
cd D:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code
python -m pip install -r tools\mock-publisher\requirements.txt
python tools\mock-publisher\publisher.py --device-id sf-mock01  # logs enabled by default
```

### 2. Verify discovery advertises logs
```powershell
mosquitto_sub -h 10.0.0.4 -p 1883 -u dev1 -P dev1pass `
  -t "skyfeeder/sf-mock01/discovery" -C 1 -v
# Look for topics.cmd_logs and topics.event_log
```

### 3. Subscribe to log events
```powershell
mosquitto_sub -h 10.0.0.4 -p 1883 -u dev1 -P dev1pass \
  -t "skyfeeder/sf-mock01/event/log" -v
```

### 4. Request dumps
```powershell
mosquitto_pub -h 10.0.0.4 -p 1883 -u dev1 -P dev1pass \
  -t "skyfeeder/sf-mock01/cmd/logs" -m '{"clear":false}'
mosquitto_pub -h 10.0.0.4 -p 1883 -u dev1 -P dev1pass \
  -t "skyfeeder/sf-mock01/cmd/logs" -m '{"clear":true}'
```
Expected results: the first command returns a JSON dump with the boot marker and recent entries; the second returns an empty buffer (`"count": 0`).

## Validation (firmware on hardware)
Follow the same four-terminal approach using your device ID. Ensure discovery advertises `cmd_logs` and `event_log` and that repeated log dumps work without resets.

## Tests
### 1. Host ring-buffer smoke test
```
clang++ -std=c++17 -DSF_LOG_ENABLE_TEST_API -I. \
  feeder-steps/15A_logging/tests/log_buffer_test.cpp logging.cpp topics.cpp \
  -o feeder-steps/15A_logging/tests/log_buffer_test.exe
feeder-steps/15A_logging/tests/log_buffer_test.exe
```
The output should match `feeder-steps/15A_logging/tests/sample_log_dump.json` (timestamps will vary).

### 2. Mock publisher unit test
```
python -m unittest discover -s tools/mock-publisher/tests -p "test_*.py"
```
This spins up the publisher with a fake MQTT client, triggers `cmd/logs`, and asserts the response.

## Boot marker check
On reset the first log entry includes `boot_reason=<value>`. Simulate by calling `SF::Log::bootMarker()` in unit tests or resetting the device; the MQTT dump should contain the marker before other entries.
