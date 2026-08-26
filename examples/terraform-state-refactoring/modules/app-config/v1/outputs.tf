output "config_parameter_name" {
  description = "Name of the app config SSM parameter."
  value       = aws_ssm_parameter.config.name
}

output "feature_flag_names" {
  description = "Names of the feature flag SSM parameters."
  value       = [for p in aws_ssm_parameter.feature_flags : p.name]
}
