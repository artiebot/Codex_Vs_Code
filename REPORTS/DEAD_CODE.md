# Dead / Legacy Code Inventory

- **`backend/presign_put.js` → `buildKey` return payload**  
  - **Evidence:** Function returns `{ key, contentType, tagging, slug }`, but the caller only destructures `key`, `contentType`, and `tagging`; `slug` is never read anywhere else in the repository. 【F:backend/presign_put.js†L68-L120】  
  - **Disposition:** Remove `slug` from the return shape (or start using it for manifest naming) to avoid confusion.

- **`ops/local/ota-server/src/index.js` → unused `entry` variable**  
  - **Evidence:** Heartbeat handler assigns `const entry = firmwareStatus.get(deviceId) || {};` but never references `entry`. 【F:ops/local/ota-server/src/index.js†L45-L53】  
  - **Disposition:** Delete the unused variable to clarify that only the new snapshot is stored.

- **`firmware/esp32/src/` directory**  
  - **Evidence:** Directory exists but contains no sources (listing is empty), while active firmware lives under `skyfeeder/`. 【037abe†L1-L2】  
  - **Disposition:** Remove or document as placeholder to prevent developers from targeting the wrong firmware tree.
