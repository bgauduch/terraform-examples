"""On-demand DynamoDB backup, invoked by a Terraform `aws_lambda_invoke` action.

The point of this demo is that an action can run *arbitrary* logic via Lambda:
here we create a timestamped on-demand backup of a DynamoDB table.
"""

import datetime

import boto3

dynamodb = boto3.client("dynamodb")


def handler(event, _context):
    table_name = event["table_name"]
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d-%H%M%S")
    backup_name = f"{table_name}-{stamp}"

    response = dynamodb.create_backup(TableName=table_name, BackupName=backup_name)
    backup_arn = response["BackupDetails"]["BackupArn"]

    print(f"Created on-demand backup {backup_name}: {backup_arn}")
    return {"backup_name": backup_name, "backup_arn": backup_arn}
