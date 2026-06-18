#!/usr/bin/env bash
#
# Create "unmanaged" infrastructure OUTSIDE Terraform (simulates ClickOps), so the
# terraform-query workflow has something real to discover and import.
#
# This directory has no providers.tf on purpose, so CI does not try to plan it.
# Tear down with ./destroy-unmanaged.sh, or - once imported - `terraform destroy`
# from ../import.
#
set -euo pipefail

REGION="${AWS_REGION:-eu-west-1}"
COUNT="${COUNT:-2}"

# Latest Amazon Linux 2023 AMI, resolved from the public SSM public parameter.
AMI=$(aws ssm get-parameter \
  --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' --output text)

echo "Launching $COUNT t3.micro instance(s) (AMI $AMI) tagged demo=clickops in $REGION ..."
aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$AMI" \
  --instance-type t3.micro \
  --count "$COUNT" \
  --tag-specifications \
  'ResourceType=instance,Tags=[{Key=demo,Value=clickops},{Key=Name,Value=clickops-unmanaged}]' \
  --query 'Instances[].InstanceId' --output text

echo
echo "Done. These instances are NOT in any Terraform state yet."
echo "Now discover and import them from ../import (see the example README)."
