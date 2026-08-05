output "platform_admin_role_arn" {
  description = "ARN of the platform administration role"
  value       = aws_iam_role.platform_admin.arn
}

output "break_glass_role_arn" {
  description = "ARN of the emergency access role"
  value       = aws_iam_role.break_glass.arn
}
