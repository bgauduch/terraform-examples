output "config_parameter_name" {
  description = "Name of the app config SSM parameter."
  value       = module.app_config.config_parameter_name
}

output "feature_flag_names" {
  description = "Names of the feature flag SSM parameters."
  value       = module.app_config.feature_flag_names
}
