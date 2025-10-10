#!/bin/bash
# Test MQTT communication with AMB82-Mini

MQTT_HOST="10.0.0.4"
MQTT_USER="dev1"
MQTT_PASS="dev1pass"
DEVICE_ID="sf-mock01"

echo "=== AMB82-Mini MQTT Test ==="
echo ""

# Test 1: Monitor all AMB topics
echo "[Test 1] Monitoring all AMB topics for 5 seconds..."
echo "Starting listener in background..."
timeout 5 mosquitto_sub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS -t "skyfeeder/$DEVICE_ID/amb/#" -v &
LISTENER_PID=$!
sleep 1

# Test 2: Send snap command
echo ""
echo "[Test 2] Sending snap command..."
mosquitto_pub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS \
  -t "skyfeeder/$DEVICE_ID/amb/camera/cmd" \
  -m '{"action":"snap"}'

echo "Command sent. Waiting for response..."
wait $LISTENER_PID 2>/dev/null

echo ""
echo "[Test 3] Check what's on the broker..."
echo "Subscribed topics:"
mosquitto_sub -h $MQTT_HOST -u $MQTT_USER -P $MQTT_PASS -t "skyfeeder/$DEVICE_ID/amb/#" -v -C 1 --retained-only 2>&1 | head -5 || echo "  (no retained messages)"

echo ""
echo "=== Test Complete ==="
echo ""
echo "If you see '========== MQTT MESSAGE RECEIVED ==========' in the AMB serial monitor,"
echo "then the callback is working. If not, the issue is with MQTT subscription."
