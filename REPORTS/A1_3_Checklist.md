# A1.3 Field Utility Checklist

Use this document to track readiness for the iOS field utility milestone. Codex updates the table whenever tasks progress; Sanaz signs off during manual validation.

| Item | Owner | Status | Notes |
| --- | --- | --- | --- |
| M1 — Project scaffolding & scripts | Codex | ⏳ | Xcode project stub + helper scripts |
| M2 — Data providers & caching | Codex | 🔜 | Providers, cache layout, eviction rules |
| M3 — App features | Codex | 🔜 | Gallery, detail, settings, offline flows |
| M4 — Tests & self-validation | Codex | 🔜 | Unit/UI tests, build logs, linting |
| M5 — Device harness | Codex | 🔜 | Arduino CLI automation, upload logs |
| M6 — Acceptance artifacts | Codex/Sanaz | 🔜 | Checklist, walkthrough, compile logs |
| AC1 — Gallery loads ≥12 items in ≤2s | Sanaz | 🔜 | Manual validation on physical device |
| AC2 — Save to Photos succeeds | Sanaz | 🔜 | Manual validation |
| AC3 — Badge resets after viewing | Sanaz | 🔜 | Manual validation |
| AC4 — Offline graceful degradation | Sanaz | 🔜 | Manual validation |
| AC5 — Artifacts captured | Codex | 🔜 | README, checklist, build logs, walkthrough |

## Notes

- Mock media generation (`Scripts/make_mock_media.swift`) and build export (`Scripts/export_build_artifacts.sh`) are available as soon as macOS tooling is connected.
- Update `/REPORTS/PLAYBOOK.md` with timestamps, commands, and links to the artifacts produced for each checklist item.
- Keep acceptance criteria un-checked until Sanaz confirms manual validation for AC1–AC4.
