# 14D - Backend Staging & Mock Publisher

## Overview
Implements a Python MQTT publisher that simulates a SkyFeeder device (`sf-mock01`). The tool seeds retained `discovery` and `status` payloads plus periodic `telemetry` so backend/app teams can exercise the contract without physical hardware.

## Files changed / created
- `tools/mock-publisher/publisher.py`
- `tools/mock-publisher/requirements.txt`
- `tools/mock-publisher/README.md`
- `feeder-steps/sf_step14C_contracts_schema_v1/README.md`
- `feeder-steps/sf_step14D_backend_staging_mock_publisher/README.md`
- `STEPS.md`

## How to run
```bash
cd tools/mock-publisher
python -m venv .venv
. .venv/Scripts/activate  # PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
python publisher.py --device-id sf-mock01
```

`Ctrl+C` stops the loop and republishes a retained offline status.

## Success criteria checklist
- [ ] Retained `discovery` + `status` appear on the dev broker (verified with `mosquitto_sub`)
- [ ] Telemetry publishes every N seconds while the script runs
- [ ] Stopping the script flips retained status to `offline`

## Troubleshooting
- **`ModuleNotFoundError: paho`**: Reactivate the virtualenv and reinstall `pip install -r requirements.txt`.
- **`Connection Refused`**: Confirm broker reachable (`ping 10.0.0.4`) and credentials (`dev1/dev1pass`).
- **No retained messages**: Ensure the script isn’t running with `--dry-run`; retained publish requires a live broker connection.

## Next step
Continue with [14E App Alpha: Discovery](../sf_step14E_app_alpha_discovery/README.md).
