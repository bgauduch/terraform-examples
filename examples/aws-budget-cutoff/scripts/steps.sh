#!/usr/bin/env bash
# Paced walkthrough of the cut-off demo. Reads values from `terraform output`, pauses on
# Enter between steps so you can narrate. Run from the example root:
#
#   MGMT_PROFILE=<mgmt> SANDBOX_PROFILE=<sandbox> ./scripts/steps.sh
#
# Self-contained: no reference to any specific session. Assumes `terraform apply` ran and the
# budget action is PENDING (arm it the evening before). If it is not PENDING yet, the TRIGGER
# step falls back to attaching the SCP directly.

set -uo pipefail

: "${MGMT_PROFILE:?export MGMT_PROFILE=<your management profile>}"
: "${SANDBOX_PROFILE:?export SANDBOX_PROFILE=<your sandbox profile>}"

ACTION_ID="$(terraform output -raw budget_action_id)"
POLICY_ID="$(terraform output -raw cutoff_surgical_policy_id)"
LAMBDA_NAME="$(terraform output -raw remediation_lambda)"
RUNAWAY_ID="$(terraform output -raw runaway_instance_id)"
APPROVE_CLI="$(terraform output -raw approve_action_cli)"
ATTACH_CLI="$(terraform output -raw manual_attach_cli)"
SANDBOX_ID="$(aws sts get-caller-identity --profile "$SANDBOX_PROFILE" --query Account --output text)"

pause() { echo; read -rp ">>> $1 (Enter) "; echo; }

echo "== AWS FinOps cut-off - live steps =="
echo "budget action : $ACTION_ID"
echo "surgical SCP  : $POLICY_ID"
echo "runaway ec2   : $RUNAWAY_ID"

pause "TRIGGER: approve the pending cut-off action (attaches the surgical SCP)"
eval "$APPROVE_CLI" || { echo "not PENDING yet -> fallback: attach the SCP directly"; eval "$ATTACH_CLI"; }

pause "FREEZE (spend-up denied): try to launch new compute"
AMI="$(aws ssm get-parameter --profile "$SANDBOX_PROFILE" --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)"
aws ec2 run-instances --profile "$SANDBOX_PROFILE" --image-id "$AMI" --instance-type m5.4xlarge --count 1 || echo "^ Denied (as intended)"

pause "HYBRID (control room stays up): read still allowed under the surgical SCP"
aws ec2 describe-instances --profile "$SANDBOX_PROFILE" --filters Name=tag:demo,Values=runaway --query 'Reservations[].Instances[].InstanceId' --output text

pause "REMEDIATION - manual: terminate the runaway (terminate is spared by the surgical SCP)"
aws ec2 terminate-instances --profile "$SANDBOX_PROFILE" --instance-ids "$RUNAWAY_ID"

pause "REMEDIATION - full-auto: invoke the remediation Lambda (terminate tagged + notify)"
aws lambda invoke --profile "$SANDBOX_PROFILE" --function-name "$LAMBDA_NAME" /dev/stdout

pause "ROLLBACK: detach the cut-off SCP - account back to normal"
aws organizations detach-policy --profile "$MGMT_PROFILE" --policy-id "$POLICY_ID" --target-id "$SANDBOX_ID"

echo "== done =="
