import serial
import threading
import time
import sys
from datetime import datetime

def monitor_port(port, baud, log_file):
    try:
        print(f"Connecting to {port}...", flush=True)
        ser = serial.Serial(port, baud, timeout=1)
        print(f"Connected to {port}. Logging to {log_file}", flush=True)
        
        with open(log_file, 'a', encoding='utf-8') as f:
            f.write(f"\n--- Session Started: {datetime.now()} ---\n")
            
            while True:
                if ser.in_waiting > 0:
                    try:
                        line = ser.readline().decode('utf-8', errors='ignore').rstrip()
                        if line:
                            timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
                            log_entry = f"[{timestamp}] {line}"
                            print(f"[{port}] {line}", flush=True)
                            f.write(log_entry + "\n")
                            f.flush()
                    except Exception as e:
                        print(f"Error reading {port}: {e}", flush=True)
                time.sleep(0.01)
                
    except serial.SerialException as e:
        print(f"Failed to open {port}: {e}", flush=True)

if __name__ == "__main__":
    # COM4 (ESP32)
    t1 = threading.Thread(target=monitor_port, args=('COM4', 115200, 'com4_log.txt'))
    t1.daemon = True
    t1.start()
    
    # COM6 (AMB82-Mini)
    t2 = threading.Thread(target=monitor_port, args=('COM6', 115200, 'com6_log.txt'))
    t2.daemon = True
    t2.start()
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Stopping monitor...")
