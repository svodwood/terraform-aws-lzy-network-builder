# VPC Foundation Module Outputs
# Provides calculated subnet configurations and validation results

output "subnet_resources" {
  description = "Flattened subnet resources ready for resource creation (one per AZ)"
  value       = local.subnet_resources
}

output "vpc_space_calculation" {
  description = "Space utilization and validation details for the VPC"
  value       = local.vpc_space_calculation
}

output "validation_errors" {
  description = "All validation errors found during configuration processing"
  value       = local.validation_errors
}
