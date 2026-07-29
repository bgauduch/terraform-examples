#!/usr/bin/env bash
# Sweeper: deletes the on-demand DynamoDB backups this lab's action created.
# `terraform destroy` removes the table but never its backups. On-demand backups
# outlive their table by design, and Terraform does not track them anyway since
# the Lambda creates them out of band. Destroy-time `action_trigger` events, which
# would let the lab clean up after itself, land in Terraform 1.16 (alpha).
#
# Usage:
#   ./sweep.sh           # list the backups (dry-run)
#   ./sweep.sh --force   # delete them
#
# Requires AWS_PROFILE to be exported. Runs before or after `terraform destroy`:
# the table name falls back to the `project` variable default once the state is gone.
# Override with TABLE_NAME=... or AWS_REGION=... if you changed the defaults.
set -euo pipefail

REGION="${AWS_REGION:-eu-west-1}"
TABLE="${TABLE_NAME:-$(terraform output -raw table_name 2>/dev/null || echo "demo-tf-actions-lambda")}"
FORCE="${1:-}"

mapfile -t ARNS < <(aws dynamodb list-backups \
  --table-name "$TABLE" \
  --region "$REGION" \
  --query 'BackupSummaries[].BackupArn' --output text | tr '\t' '\n')

if [ "${#ARNS[@]}" -eq 0 ] || [ -z "${ARNS[0]:-}" ]; then
  echo "No on-demand backup left for ${TABLE}."
  exit 0
fi

echo "On-demand backups for ${TABLE}:"
printf '  %s\n' "${ARNS[@]}"

if [ "$FORCE" != "--force" ]; then
  echo "Dry-run. Re-run with --force to delete them."
  exit 0
fi

for arn in "${ARNS[@]}"; do
  echo "Deleting ${arn##*/} ..."
  aws dynamodb delete-backup --backup-arn "$arn" --region "$REGION" >/dev/null
done
echo "Cleanup done."
