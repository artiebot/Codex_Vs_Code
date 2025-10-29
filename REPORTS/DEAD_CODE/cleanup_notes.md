# Dead Code Cleanup Notes

- Removed the unused `slug` return value from `backend/presign_put.js` so the helper no longer surfaces dead data. ✅
- Added a README placeholder under `firmware/esp32/src/` to explain why the directory stays in version control until ESP32 sources land. ✅
- Cleared the unused `entry` variable in the OTA heartbeat handler while wiring persistence; no other unused symbols detected in that module. ✅
