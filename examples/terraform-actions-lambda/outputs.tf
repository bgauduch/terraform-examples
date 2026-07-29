output "table_name" {
  description = "Name of the DynamoDB table whose lifecycle triggers the backup"
  value       = aws_dynamodb_table.this.name
}

output "lambda_function_name" {
  description = "Name of the Lambda function invoked by the action"
  value       = aws_lambda_function.backup.function_name
}

output "list_backups_command" {
  description = "Handy CLI to see the backups created by the action"
  value       = "aws dynamodb list-backups --table-name ${aws_dynamodb_table.this.name} --region ${var.region}"
}
