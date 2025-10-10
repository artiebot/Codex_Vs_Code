#!/bin/bash
# AMB82-Mini Flash Script
# Flashes compiled firmware to AMB82-Mini board

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
AMB_DIR="$(dirname "$SCRIPT_DIR")"
SKETCH_PATH="$AMB_DIR/amb-mini.ino"
BUILD_PATH="$AMB_DIR/build"
FQBN="realtek:amebad:amebad"

# Port can be specified as argument, otherwise auto-detect
PORT="${1:-}"

echo "=== AMB82-Mini Flash Script ==="
echo ""

# Check if arduino-cli is installed
if ! command -v arduino-cli &> /dev/null; then
    echo "ERROR: arduino-cli not found"
    echo "Install from: https://arduino.github.io/arduino-cli/latest/installation/"
    exit 1
fi

# Check if firmware is built
if [ ! -d "$BUILD_PATH" ]; then
    echo "ERROR: Build directory not found. Run ./scripts/build.sh first"
    exit 1
fi

# Auto-detect port if not specified
if [ -z "$PORT" ]; then
    echo "[1/2] Detecting AMB82-Mini..."
    PORTS=$(arduino-cli board list | grep -i "realtek\|amb\|serial" | awk '{print $1}' || true)

    if [ -z "$PORTS" ]; then
        echo "ERROR: No board detected. Please:"
        echo "  1. Connect AMB82-Mini via USB"
        echo "  2. Install USB drivers (CP2102)"
        echo "  3. Or specify port: ./scripts/flash.sh COM3"
        exit 1
    fi

    # Use first detected port
    PORT=$(echo "$PORTS" | head -n1)
    echo "Detected port: $PORT"
else
    echo "[1/2] Using specified port: $PORT"
fi

# Upload firmware
echo ""
echo "[2/2] Uploading firmware..."
arduino-cli upload \
    --fqbn "$FQBN" \
    --port "$PORT" \
    --input-dir "$BUILD_PATH" \
    "$SKETCH_PATH"

echo ""
echo "========== FLASH COMPLETE =========="
echo "Board should now be running new firmware"
echo ""
echo "To monitor serial output:"
echo "  arduino-cli monitor -p $PORT -c baudrate=115200"
echo ""
echo "Or use Arduino IDE: Tools → Serial Monitor (115200 baud)"
