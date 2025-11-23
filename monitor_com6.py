#!/usr/bin/env python3
import serial
import time
import sys

try:
    print("Opening COM6 at 115200 baud...", flush=True)
    ser = serial.Serial('COM6', 115200, timeout=1)
    print("Connected. Reading serial output (Ctrl+C to stop)...\n", flush=True)

    start_time = time.time()
    timeout = 300  # 5 minutes

    while (time.time() - start_time) < timeout:
        if ser.in_waiting > 0:
            try:
                line = ser.readline().decode('utf-8', errors='ignore').rstrip()
                if line:
                    print(line, flush=True)
            except Exception as e:
                pass
        time.sleep(0.1)

    print("\n[Timeout reached]")
    ser.close()

except serial.SerialException as e:
    print(f"Error opening COM6: {e}", flush=True)
    print("Is the AMB mini connected and powered on?")
    sys.exit(1)
except KeyboardInterrupt:
    print("\n[Stopped by user]")
    ser.close()
