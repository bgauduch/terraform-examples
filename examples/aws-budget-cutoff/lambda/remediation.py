"""Cut-off remediation: terminate the tagged runaway instance(s), then notify.

Off the critical path - the SCP attach already froze new spend. This layer makes the
bill go back down (terminate) and closes the loop with a notification.

Trigger in the demo: direct `aws lambda invoke`. In prod: an EventBridge rule on the
Organizations AttachPolicy event. The event payload is ignored - remediation is idempotent
and always acts on the tag filter.
"""

import os

import boto3

TAG_KEY = os.environ["RUNAWAY_TAG_KEY"]
TAG_VALUE = os.environ["RUNAWAY_TAG_VALUE"]
TOPIC_ARN = os.environ["NOTIFY_TOPIC_ARN"]

ec2 = boto3.client("ec2")
sns = boto3.client("sns")


def handler(event, context):
    reservations = ec2.describe_instances(
        Filters=[
            {"Name": f"tag:{TAG_KEY}", "Values": [TAG_VALUE]},
            {"Name": "instance-state-name", "Values": ["pending", "running", "stopping", "stopped"]},
        ]
    )["Reservations"]

    instance_ids = [i["InstanceId"] for r in reservations for i in r["Instances"]]

    if instance_ids:
        ec2.terminate_instances(InstanceIds=instance_ids)
        message = f"Cut-off remediation: terminated runaway instance(s) {', '.join(instance_ids)}."
    else:
        message = "Cut-off remediation: no runaway instance found (already clean)."

    sns.publish(TopicArn=TOPIC_ARN, Subject="AWS cut-off remediation", Message=message)
    return {"terminated": instance_ids, "message": message}
