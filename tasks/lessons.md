# Repo lessons

Durable lessons learned while working in this repository. Append new entries; keep them short and actionable.

## CI

- **Trivy single-scan + convert** - run `trivy config . --format json --output trivy.json --exit-code 0` once, then drive both the report and the gate from that one JSON with `trivy convert`: `--severity MEDIUM,HIGH,CRITICAL --exit-code 0` for visibility and `--severity HIGH,CRITICAL --exit-code 1` to block. Scanning once and converting twice keeps a single source of truth and avoids re-scanning per severity. Install the CLI with the pinned `aquasecurity/setup-trivy` action (pin the trivy `version:` too) rather than the all-in-one `trivy-action`, so the raw `trivy` commands are available in the step.
