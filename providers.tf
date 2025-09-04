# Provider Configuration
# Main AWS provider for the network account
provider "aws" {
  # Use AWS profile for authentication
  # Ensure your AWS profile is configured for the network account
  profile = var.network_account_profile
  region  = split(".", basename(var.hub_definition))[0]
}

# Dynamic provider configuration for spoke accounts using account-{account_id} profile convention
# Extracts account IDs directly from the networks configuration file
provider "aws" {
  alias = "principal_account"
  for_each = var.spokes_definition != "" ? toset([
    for vpc_name, vpc_config in yamldecode(file(var.spokes_definition)) : tostring(vpc_config.account)
  ]) : toset([])

  profile = "account-${each.key}"
  region  = split(".", basename(var.spokes_definition))[0]
}
