#!/usr/bin/env bash
# Sweeper: deletes the on-demand DynamoDB backups this lab's action created (BackupType USER).
# `terraform destroy` removes the table but never its backups. On-demand backups
# outlive their table by design, and Terraform does not track them anyway since
# the Lambda creates them out of band. Destroy-time `action_trigger` events, which
# would let the lab clean up after itself, land in Terraform 1.16 (alpha).
#
# SYSTEM backups are listed but never deleted. DynamoDB creates one when a table with PITR
# enabled is deleted, names it <table>$DeletedTableBackup, keeps it 35 days at no cost and
# rejects any delete attempt. See "Delete a table with PITR enabled":
# https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery_Howitworks.html
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

# System backups are reported, never deleted: DynamoDB creates one when a table with PITR
# enabled is deleted, keeps it 35 days at no cost, and refuses any attempt to remove it.
mapfile -t SYSTEM < <(aws dynamodb list-backups \
  --table-name "$TABLE" \
  --region "$REGION" \
  --backup-type SYSTEM \
  --query 'BackupSummaries[].[BackupName,BackupExpiryDateTime]' --output text)

if [ "${#SYSTEM[@]}" -gt 0 ] && [ -n "${SYSTEM[0]:-}" ]; then
  echo "System backups (kept by DynamoDB after the table was deleted, free, not deletable):"
  printf '  %s\n' "${SYSTEM[@]}"
  echo "  They expire on their own, 35 days after the deletion."
fi

# `list-backups` defaults to USER anyway; the flag is explicit so the intent survives a reread.
mapfile -t ARNS < <(aws dynamodb list-backups \
  --table-name "$TABLE" \
  --region "$REGION" \
  --backup-type USER \
  --query 'BackupSummaries[].BackupArn' --output text | tr '\t' '\n')

if [ "${#ARNS[@]}" -eq 0 ] || [ -z "${ARNS[0]:-}" ]; then
  echo "No user backup left for ${TABLE}."
  exit 0
fi

echo "User backups for ${TABLE}, created by the action:"
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
