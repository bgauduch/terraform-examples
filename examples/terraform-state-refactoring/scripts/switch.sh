#!/usr/bin/env bash
# Overlay a step snapshot into live/ - the state stays put, only the .tf files
# change. This replaces live commenting/uncommenting during a demo.
set -euo pipefail

step="${1:?usage: switch.sh <step-1|step-2|step-3|step-4|step-5|step-5b|step-6>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/$step"

[ -d "$src" ] || { echo "unknown step: $step" >&2; exit 1; }

rm -f "$root"/live/*.tf
cp "$src"/*.tf "$root/live/"

echo "live/ is now at $step (state untouched)."
echo "next: cd live && terraform init && terraform plan"
