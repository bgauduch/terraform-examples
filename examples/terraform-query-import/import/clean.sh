#!/usr/bin/env bash
#
# Reset the import root module to a pristine state so the demo can be replayed.
# Removes the live demo artifacts (generated config, local state, provider cache)
# but keeps the committed files (.terraform.lock.hcl, providers.tf, etc.).
#
# This does NOT touch AWS: if the instances are still running, tear them down
# first - `terraform destroy` (if imported) or ../bootstrap/destroy-unmanaged.sh.
#
set -euo pipefail

cd "$(dirname "$0")"

rm -rf .terraform/
rm -f generated.tf terraform.tfstate terraform.tfstate.backup

echo "Cleaned: .terraform/, generated.tf, terraform.tfstate*. Ready for a fresh run."
