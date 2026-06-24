#!/usr/bin/env bash
# Sweeper: cleans up orphaned test buckets (left by a `terraform test` interrupted
# before its auto-destroy). Targets resources carrying the suite tag.
# Tag source of truth: providers.tf (default_tags tftest-suite).
#
# Usage:
#   ./sweep.sh           # list tagged buckets (dry-run)
#   ./sweep.sh --force   # empty then delete each tagged bucket
#
# Requires AWS_PROFILE (e.g. sandbox). Tooled alternative: aws-nuke / awsweeper
# filtered on the same tag.
set -euo pipefail

TAG_KEY="tftest-suite"
TAG_VALUE="terraform-module-testing"
REGION="${AWS_REGION:-eu-west-1}"
FORCE="${1:-}"

mapfile -t ARNS < <(aws resourcegroupstaggingapi get-resources \
  --region "$REGION" \
  --tag-filters "Key=${TAG_KEY},Values=${TAG_VALUE}" \
  --resource-type-filters "s3" \
  --query 'ResourceTagMappingList[].ResourceARN' --output text | tr '\t' '\n')

if [ "${#ARNS[@]}" -eq 0 ] || [ -z "${ARNS[0]:-}" ]; then
  echo "No bucket tagged ${TAG_KEY}=${TAG_VALUE}."
  exit 0
fi

echo "Tagged buckets found:"
printf '  %s\n' "${ARNS[@]}"

if [ "$FORCE" != "--force" ]; then
  echo "Dry-run. Re-run with --force to empty + delete."
  exit 0
fi

for arn in "${ARNS[@]}"; do
  bucket="${arn##*:::}"
  echo "Deleting ${bucket} ..."
  aws s3 rm "s3://${bucket}" --recursive >/dev/null 2>&1 || true
  aws s3api delete-bucket --bucket "${bucket}" --region "$REGION"
done
echo "Cleanup done."
