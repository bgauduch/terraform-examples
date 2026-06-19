#!/usr/bin/env bash
#
# Create "unmanaged" infrastructure OUTSIDE Terraform (simulates ClickOps), so the
# terraform-query workflow has something real to discover and import.
#
# Launches two *categories* of EC2 instances tagged demo=clickops, to demonstrate
# segmented bulk import (one list block per instance-type, see ../import/search.tfquery.hcl):
#   - tier=general : t3.micro   (stand-in for a general-purpose fleet)
#   - tier=compute : t3.small   (stand-in for a GPU/compute fleet, e.g. g5.* in prod)
#
# This directory has no providers.tf on purpose, so CI does not try to plan it.
# Tear down with ./destroy-unmanaged.sh, or - once imported - `terraform destroy`
# from ../import.
#
set -euo pipefail

REGION="${AWS_REGION:-eu-west-1}"
GENERAL_TYPE="${GENERAL_TYPE:-t3.micro}"
COMPUTE_TYPE="${COMPUTE_TYPE:-t3.small}"

# Persist launched instance IDs here (gitignored) so they can be referenced later
# without re-querying AWS. Not required for teardown - destroy-unmanaged.sh finds
# them by tag.
IDS_FILE="$(dirname "$0")/created-instances.txt"
: >"$IDS_FILE"

# Latest Amazon Linux 2023 AMI, resolved from the public SSM public parameter.
AMI=$(aws ssm get-parameter \
  --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' --output text)

# Idempotent: only launch a tier if no live instance already carries its tags.
launch() {
  local tier="$1" type="$2" id
  id=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:demo,Values=clickops" "Name=tag:tier,Values=$tier" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' --output text)

  if [ -n "$id" ]; then
    echo "Already present: tier=$tier -> $id (skipping)"
  else
    echo "Launching 1 $type instance (AMI $AMI) tagged demo=clickops tier=$tier in $REGION ..."
    # Minimal hardening, no extra infra needed:
    #   - no public IP: instance is not reachable from the Internet (the default
    #     SG already blocks all inbound from outside itself).
    #   - IMDSv2 required + hop limit 1: protects role credentials from SSRF.
    #   - encrypted root volume, deleted on termination.
    id=$(aws ec2 run-instances \
      --region "$REGION" \
      --image-id "$AMI" \
      --instance-type "$type" \
      --count 1 \
      --no-associate-public-ip-address \
      --metadata-options "HttpTokens=required,HttpPutResponseHopLimit=1,HttpEndpoint=enabled" \
      --block-device-mappings \
      '[{"DeviceName":"/dev/xvda","Ebs":{"Encrypted":true,"DeleteOnTermination":true}}]' \
      --tag-specifications \
      "ResourceType=instance,Tags=[{Key=demo,Value=clickops},{Key=tier,Value=$tier},{Key=Name,Value=clickops-$tier}]" \
      --query 'Instances[].InstanceId' --output text)
  fi

  echo "$id" >>"$IDS_FILE"
}

launch general "$GENERAL_TYPE"
launch compute "$COMPUTE_TYPE"

echo
echo "Done. These instances are NOT in any Terraform state yet."
echo "Now discover and import them from ../import (see the example README)."
