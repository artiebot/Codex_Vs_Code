# Fastlane Match Setup for TestFlight Automation

SkyFeeder Field Utility now manages signing assets entirely through fastlane match and GitHub Actions. You no longer need access to a local Mac to create or refresh certificates—everything can be bootstrapped and maintained from CI.

## Required GitHub Secrets

Add the following repository secrets (Settings → Secrets and variables → Actions):

| Secret | Description |
| --- | --- |
| `MATCH_GIT_URL` | HTTPS or SSH URL of the private certificates repo (fastlane match storage). |
| `MATCH_PASSWORD` | Passphrase used to encrypt the match repository. |
| `ASC_ISSUER_ID` | App Store Connect API key issuer UUID. |
| `ASC_KEY_ID` | App Store Connect API key identifier. |
| `ASC_API_KEY_P8` | Contents of the `.p8` App Store Connect API key (can be raw PEM or base64). |
| `TEAM_ID` | Ten-character Apple Developer Team ID (e.g., `ABC123XYZA`). |

> Optional: if your certificates repo uses deploy keys or a PAT, bake the credential into `MATCH_GIT_URL` (HTTPS token) or configure the runner to inject an SSH key.

## CI Bootstrap (Recommended)

1. Ensure the secrets above are present.
2. Navigate to **Actions → Match Bootstrap → Run workflow**.
3. Confirm the run succeeds. It will:
   - Select Xcode on the hosted macOS runner.
   - Install fastlane (using the root Gemfile).
   - Execute `fastlane match` with `readonly:false`, which creates the App Store distribution certificate + provisioning profile, encrypts them with `MATCH_PASSWORD`, and pushes to `MATCH_GIT_URL`.

After the bootstrap completes, the standard **iOS TestFlight** workflow automatically:

1. Calls `fastlane match` in `readonly:true` mode to pull certs/profiles for each build.
2. Runs the `testflight_upload` lane, which now:
   - Generates an App Store Connect API key on the fly.
   - Invokes `match` again (safety for local runs).
   - Builds with `gym export_team_id:$TEAM_ID` and `xcargs "-allowProvisioningUpdates CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=$TEAM_ID"`.
   - Uploads the IPA to TestFlight with the same API key.

## Manual Bootstrap (Optional Legacy Path)

If you prefer to stage certs locally you can still:

1. Clone this repo and `cd mobile/ios-field-utility`.
2. Run `fastlane match appstore --app_identifier com.skyfeeder.field`.
3. Push the generated files to your private certificates repo.

This manual approach requires Xcode + fastlane on a Mac and is no longer necessary unless you are debugging certificates offline.

## Maintenance & Troubleshooting

- **Renewals:** Re-run the **Match Bootstrap** workflow (or `fastlane match nuke distribution` locally followed by the bootstrap) when Apple revokes/renews distribution certs.
- **Secret Rotation:** Update `MATCH_PASSWORD`, tokens embedded in `MATCH_GIT_URL`, or the App Store Connect API key at any time; rerun the bootstrap workflow afterward.
- **CI Failures:** Inspect the `Pull signing (match)` step in the **iOS TestFlight** workflow. Common causes are incorrect repo URL, missing passphrase, or expired API keys.

With these workflows in place, every TestFlight upload uses the exact same signing artifacts, and the entire fleet can be re-provisioned from GitHub Actions without touching a local machine.

## Troubleshooting Log

- **2025-11-08 — CI signing conflict:** Pipeline failed with “SkyFeederFieldUtility has conflicting provisioning settings” because the project was in automatic signing while `PROVISIONING_PROFILE_SPECIFIER` was set by fastlane. Resolved by forcing manual signing (`CODE_SIGN_STYLE=Manual`) in both `AppConfig.xcconfig` and the fastlane lane so the explicit provisioning profile matches the signing mode.
- **2025-11-08 — Signing hang (Keychain mismatch):** `bundle exec fastlane testflight_upload` kept stalling at “Signing …” because `match` silently imported certs into `login.keychain`, while the workflow unlocked `build.keychain`. Fastlane now defaults to `build.keychain` on CI and re-applies `security set-key-partition-list` whenever `MATCH_KEYCHAIN_NAME/PASSWORD` aren’t provided, preventing the prompt that was blocking codesign.
- **2025-11-08 — Missing keychain on local runs:** Running `bundle exec fastlane run match` outside CI failed with “Could not locate the provided keychain” because `build.keychain` only exists on the GitHub runner. The fastlane lane now detects whether the requested keychain file exists and falls back to `login.keychain` locally, so we avoid repeating the same fix when switching environments.
