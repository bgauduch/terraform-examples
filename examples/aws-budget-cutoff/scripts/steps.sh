#!/usr/bin/env bash
# Paced walkthrough of the cut-off demo. Reads values from `terraform output`, pauses on
# Enter between steps so you can narrate. Run from the example root:
#
#   MGMT_PROFILE=<mgmt> SANDBOX_PROFILE=<sandbox> ./scripts/steps.sh
#
# Self-contained: no reference to any specific session. Assumes `terraform apply` ran and the
# budget action is PENDING (arm it the evening before). If it is not PENDING yet, the TRIGGER
# step falls back to attaching the SCP directly.
#
# Screen-share safe: every AWS CLI call is silenced (>/dev/null) and replaced by a hand-written
# status line. No raw JSON - account IDs, ARNs, credentials - is ever printed to the terminal,
# which a browser account-id blur extension does NOT cover.

set -uo pipefail

: "${MGMT_PROFILE:?export MGMT_PROFILE=management}"
: "${SANDBOX_PROFILE:?export SANDBOX_PROFILE=sandbox}"
REGION="${AWS_REGION:-eu-west-1}"

clear # start from a clean terminal - no prior scrollback on screen

ACTION_ID="$(terraform output -raw budget_action_id)"
POLICY_ID="$(terraform output -raw cutoff_surgical_policy_id)"
LAMBDA_NAME="$(terraform output -raw remediation_lambda)"
RUNAWAY_ID="$(terraform output -raw runaway_instance_id)"
BREAK_GLASS_ARN="$(terraform output -raw break_glass_role_arn)"
APPROVE_CLI="$(terraform output -raw approve_action_cli)"
ATTACH_CLI="$(terraform output -raw manual_attach_cli)"
SANDBOX_ID="$(aws sts get-caller-identity --profile "$SANDBOX_PROFILE" --query Account --output text)"

pause() { echo; read -rp ">>> $1 (Enter) "; echo; }

# Resource IDs below are non-secret (no account IDs); shown for on-screen orientation.
echo "== AWS FinOps cut-off - live steps =="
echo "budget action : $ACTION_ID"
echo "surgical SCP  : $POLICY_ID"
echo "runaway ec2   : $RUNAWAY_ID"

pause "TRIGGER: approve the pending cut-off action (attaches the surgical SCP)"
if eval "$APPROVE_CLI" >/dev/null 2>&1; then
  echo "cut-off action APPROVED -> surgical SCP attaching to sandbox"
else
  echo "action not PENDING -> fallback: attaching the SCP directly"
  eval "$ATTACH_CLI" >/dev/null 2>&1 && echo "surgical SCP attached" || echo "attach failed - narrate"
fi

pause "FREEZE (spend-up denied): launching new EC2 compute"
AMI="$(aws ssm get-parameter --profile "$SANDBOX_PROFILE" --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)"
if aws ec2 run-instances --profile "$SANDBOX_PROFILE" --image-id "$AMI" --instance-type m5.4xlarge --count 1 >/dev/null 2>&1; then
  echo "UNEXPECTED: instance launched (SCP not attached?)"
else
  echo "run-instances DENIED - explicit deny in the surgical SCP (as intended)"
fi

pause "FREEZE (spend-up denied): invoking Bedrock is blocked too"
if aws bedrock-runtime invoke-model --profile "$SANDBOX_PROFILE" --region "$REGION" \
  --model-id anthropic.claude-3-haiku-20240307-v1:0 \
  --cli-binary-format raw-in-base64-out \
  --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":8,"messages":[{"role":"user","content":"hi"}]}' \
  /dev/null >/dev/null 2>&1; then
  echo "UNEXPECTED: Bedrock responded (SCP not attached?)"
else
  echo "bedrock:InvokeModel DENIED - explicit deny in the surgical SCP (as intended)"
fi

pause "HYBRID (control room stays up): read still allowed under the surgical SCP"
RUNNING="$(aws ec2 describe-instances --profile "$SANDBOX_PROFILE" --filters Name=tag:demo,Values=runaway --query 'Reservations[].Instances[].InstanceId' --output text)"
echo "describe-instances OK - runaway still visible: ${RUNNING:-<none>}"

pause "HYBRID (control room stays up): the break-glass role can still be assumed"
if aws sts assume-role --profile "$SANDBOX_PROFILE" --role-arn "$BREAK_GLASS_ARN" --role-session-name live-demo >/dev/null 2>&1; then
  echo "break-glass role STILL assumable - credentials obtained (hidden)"
else
  echo "(assume needs sts:AssumeRole on the caller - narrate if your SSO role lacks it)"
fi

pause "REMEDIATION - full-auto: invoke the Lambda (finds the tagged runaway, terminates it, notifies)"
LAMBDA_OUT="$(mktemp)"
if aws lambda invoke --profile "$SANDBOX_PROFILE" --function-name "$LAMBDA_NAME" "$LAMBDA_OUT" >/dev/null 2>&1; then
  echo "Lambda ran -> $(jq -r '.message' "$LAMBDA_OUT" 2>/dev/null || cat "$LAMBDA_OUT")"
else
  echo "Lambda invoke failed - narrate"
fi
rm -f "$LAMBDA_OUT"

pause "REMEDIATION - manual (the same move by hand): terminate is spared by the surgical SCP"
STATE="$(aws ec2 terminate-instances --profile "$SANDBOX_PROFILE" --instance-ids "$RUNAWAY_ID" --query 'TerminatingInstances[].CurrentState.Name' --output text 2>/dev/null)"
echo "terminate-instances OK - runaway now: ${STATE:-already gone}"

pause "ROLLBACK: detach the cut-off SCP - account back to normal"
aws organizations detach-policy --profile "$MGMT_PROFILE" --policy-id "$POLICY_ID" --target-id "$SANDBOX_ID" >/dev/null 2>&1 \
  && echo "surgical SCP detached - sandbox back to normal" || echo "detach failed - narrate"

echo "== done =="
