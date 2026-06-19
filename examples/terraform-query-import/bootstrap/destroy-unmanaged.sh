#!/usr/bin/env bash
#
# Terminate the unmanaged demo instances by tag. Use this only if you did NOT
# import them; once imported, tear them down with `terraform destroy` from ../import.
#
set -euo pipefail

REGION="${AWS_REGION:-eu-west-1}"

# --output text tab-separates IDs; collapse to space-separated for clean display
# and word-splitting into the terminate call.
ids=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:demo,Values=clickops" \
  "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text | tr '\t' ' ')

if [ -z "$ids" ]; then
  echo "No clickops-tagged instances to terminate in $REGION."
  exit 0
fi

echo "Terminating $(echo "$ids" | wc -w | tr -d ' ') instance(s): $ids"
aws ec2 terminate-instances --region "$REGION" --instance-ids $ids >/dev/null

# Drop the local ID file written by create-unmanaged.sh, if present.
rm -f "$(dirname "$0")/created-instances.txt"
