#!/usr/bin/env bash
#
# Version: 2.0
# Changelog:
#   2026-08-26 - v2.0 - print the .tf diff on each switch (the change IS the lesson)
#   2026-08-25 - v1.0 - overlay a step snapshot into live/, state untouched
# Overlay a step snapshot into live/ - the state stays put, only the .tf files
# change. This replaces live commenting/uncommenting during a demo.
# The diff of the .tf files is printed: what changed IS the lesson of each step.
set -euo pipefail

step="${1:?usage: switch.sh <step-1|step-2|step-3|step-4|step-5|step-5b|step-6>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/$step"

[ -d "$src" ] || { echo "unknown step: $step" >&2; exit 1; }

# Snapshot the .tf files only: .terraform/ and lock files are runtime noise.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/before" "$work/after"
cp "$root"/live/*.tf "$work/before/" 2>/dev/null || true
cp "$src"/*.tf "$work/after/"

echo "=== $step - what changed in live/ ==="
git --no-pager diff --no-index --color=always -- "$work/before" "$work/after" 2>/dev/null \
  | sed -E "s#[0-9]?$work/before#a#g; s#[0-9]?$work/after#b#g" || true

rm -f "$root"/live/*.tf
cp "$src"/*.tf "$root/live/"

echo "=== live/ is now at $step (state untouched) ==="
echo "next: cd live && terraform init && terraform plan"
