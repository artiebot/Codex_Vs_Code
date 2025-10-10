#!/bin/bash
# AMB82-Mini Build Script
# Builds the AMB firmware using arduino-cli

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
AMB_DIR="$(dirname "$SCRIPT_DIR")"
SKETCH_PATH="$AMB_DIR/amb-mini.ino"
BUILD_PATH="$AMB_DIR/build"
FQBN="realtek:amebad:amebad"

echo "=== AMB82-Mini Build Script ==="
echo "Sketch: $SKETCH_PATH"
echo "Build path: $BUILD_PATH"
echo ""

# Check if arduino-cli is installed
if ! command -v arduino-cli &> /dev/null; then
    echo "ERROR: arduino-cli not found"
    echo "Install from: https://arduino.github.io/arduino-cli/latest/installation/"
    exit 1
fi

# Check if sketch exists
if [ ! -f "$SKETCH_PATH" ]; then
    echo "ERROR: Sketch not found at $SKETCH_PATH"
    exit 1
fi

# Ensure board core is installed
echo "[1/3] Checking board support..."
if ! arduino-cli core list | grep -q "realtek:amebad"; then
    echo "Installing Realtek AMB board support..."
    arduino-cli core update-index --additional-urls https://github.com/ambiot/ambd_arduino/raw/master/Arduino_package/package_realtek.com_amebad_index.json
    arduino-cli core install realtek:amebad --additional-urls https://github.com/ambiot/ambd_arduino/raw/master/Arduino_package/package_realtek.com_amebad_index.json
else
    echo "Board support OK"
fi

# Install required libraries
echo ""
echo "[2/3] Installing libraries..."
arduino-cli lib install PubSubClient || true
arduino-cli lib install ArduinoJson || true

# Compile the sketch
echo ""
echo "[3/3] Compiling firmware..."
mkdir -p "$BUILD_PATH"
arduino-cli compile \
    --fqbn "$FQBN" \
    --build-path "$BUILD_PATH" \
    --warnings default \
    "$SKETCH_PATH"

# Show build artifacts
echo ""
echo "========== BUILD COMPLETE =========="
if [ -d "$BUILD_PATH" ]; then
    echo "Firmware artifacts:"
    ls -lh "$BUILD_PATH"/*.bin 2>/dev/null || echo "  (no .bin files)"
    ls -lh "$BUILD_PATH"/*.elf 2>/dev/null || echo "  (no .elf files)"
fi

echo ""
echo "To flash: ./scripts/flash.sh [PORT]"
