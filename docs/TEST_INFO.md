# External Testing Focus

The TestFlight build targets validation of the gallery workflow with local and presigned providers. External testers should cover the following scenarios:

1. **Gallery refresh** - Pull to refresh in Settings + Presigned HTTP mode and confirm new captures appear without relaunching.
2. **Save to Photos** - Enable the *Auto-save downloads to Photos* toggle, open any capture, and verify it lands in the iOS Photos app (permission prompt expected on first run).
3. **Badge behavior** - Leave the gallery, trigger a new upload, and confirm the app icon badge increments. Opening the gallery again should clear the badge.
4. **Share sheet** - From a capture detail screen, tap **Share capture** and select *Save to Files* to ensure the cached asset exports successfully.
5. **Offline mode** - Switch the device to airplane mode (or disable Wi-Fi) while Presigned HTTP is active and confirm the offline banner appears, cached captures remain viewable, and no crashes occur when refreshing.

Document results, device identifiers, and any anomalies in `REPORTS/A1.3/ios_run_notes.md`.
