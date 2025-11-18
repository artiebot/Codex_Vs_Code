# SkyFeeder Local Provisioning Guide

This guide summarizes the updated provisioning flow introduced in **B1 – Provisioning polish**. Use it during local bring-up or when coaching an operator through the captive portal workflow.

## 1. Triggering Setup Mode

You can enter the captive portal in two ways:

1. **Long press** – Hold the physical provision button for ~4 seconds until the LED switches to the provisioning pattern (solid amber pulse).  
2. **Triple power cycle** – Power the device on/off three times in quick succession (each cycle <10 s of uptime). On the third boot the firmware automatically enters setup mode. The counter resets once the device stays connected for ~2 minutes.

## 2. Captive Portal Access

When setup mode is active the ESP32 exposes an AP named `SkyFeeder-Setup`. Connect to it from a laptop or phone, then open any browser (DNS is hijacked to serve the portal). Fill in the Wi-Fi fields (SSID + password and device ID) and click **Save & Reboot**.

Key notes:

- Blank fields fall back to firmware defaults (`config.h`).  
- Credentials persist in NVS; the portal no-ops if required fields are missing.  
- After submission the LED switches to the blue heartbeat pattern while the ESP32 attempts to join the configured Wi-Fi.

## 3. LED States (Quick Reference)

| State | Pattern | Meaning |
|-------|---------|---------|
| Provisioning | Soft amber warn | Captive portal active (AP mode) |
| Connecting Wi-Fi | Blue heartbeat | Attempting to join Wi-Fi |
| Online | Solid green | Connected on HTTP/WS control plane |
| Auto | (default UX) | Reverts to power-state driven patterns once stable |

## 4. Stability + Recovery

- The firmware clears the power-cycle counter after ~2 minutes of uninterrupted Wi-Fi connectivity.  
- Once stable, the LED controller returns to the normal power-state driven behavior.  
- If connectivity drops the LED reverts to the blue heartbeat while the Wi-Fi manager re-establishes the link.
- Wi-Fi failures are tracked over time: **transient drops just trigger background retries**, but if roughly three connection attempts fail within the configured window (default ~30 minutes) the device **automatically re-enters provisioning mode** instead of silently staying offline.

## 5. Operator Checklist (Local)

1. Power the device and confirm the **green online** LED once provisioning completes.  
2. Triple-tap power to verify recovery (device should enter portal automatically).  
3. Re-enter credentials, ensure the LED transitions from amber → blue → green.  
4. Confirm the device is reachable on the LAN (e.g., `curl http://<device-ip>/` or via the local gallery/health endpoints).  
5. Capture a short video/screenshots of the portal + LED transitions for `REPORTS/B1/provisioning_demo.mp4`.

With these updates the provisioning flow should be repeatable without flashing new firmware, and operators have visible LED feedback for each stage.
