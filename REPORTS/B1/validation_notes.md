# B1 Provisioning Validation Notes

Automated validation:
- Triple power cycle counter stored in NVS, auto-enters captive portal on 3rd boot (see provisioning logs).
- LED state machine: amber (portal), blue heartbeat (Wi-Fi connect), solid green (MQTT online).
- Captive portal save clears counter and reboots into CONNECTING state.

Manual steps still required:
1. Record a short demo video of the provisioning flow (`REPORTS/B1/provisioning_demo.mp4`).
2. Exercise triple power cycle on hardware to generate the video + confirm LED transitions.
3. Verify operator guide steps with a fresh device and note any UX friction.
