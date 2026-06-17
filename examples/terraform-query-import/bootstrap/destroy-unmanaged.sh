#!/usr/bin/env bash
#
# Terminate the unmanaged demo instances by tag. Use this only if you did NOT
# import them; once imported, tear them down with `terraform destroy` from ../import.
#
set -euo pipefail

REGION="${AWS_REGION:-eu-west-1}"

ids=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:demo,Values=clickops" \
  "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text)

if [ -z "$ids" ]; then
  echo "No clickops-tagged instances to terminate in $REGION."
  exit 0
fi

echo "Terminating: $ids"
aws ec2 terminate-instances --region "$REGION" --instance-ids $ids \
  --query 'TerminatingInstances[].InstanceId' --output text
