# Basic Deployment Example

This example demonstrates how to deploy LZYNetworkBuilder with:
- A hub VPC for centralized networking
- Multiple spoke VPCs for workloads
- AWS Network Firewall for security

## Prerequisites

1. **AWS Organizations**: Ensure RAM sharing is enabled
2. **AWS Accounts**: Minimum of 2 accounts (hub + 1 spoke)
3. **AWS Profiles**: Configure profiles for account access
4. **OpenTofu**: Version >= 1.5 required

## Example Configuration Files

- `../hub/us-east-1.yaml`: Example Hub VPC definition
- `../spokes/us-east-1.yaml`: Example Spoke VPC definitions

## Firewall Configuration

This example uses AWS Network Firewall for centralized security inspection. The `firewall_type` variable controls which firewall infrastructure is deployed:

### AWS Network Firewall (Default)
```hcl
firewall_type = "aws_network_firewall"
```
- **What it does**: Deploys AWS managed Network Firewall in the hub VPC
- **Management**: AWS managed service, no infrastructure to maintain

### Gateway Load Balancer (Alternative)
```hcl
firewall_type = "gateway_load_balancer"
```
- **What it does**: Deploys Gateway Load Balancer infrastructure for third-party appliances
- **Use case**: When you need Palo Alto, Fortinet, or other security appliances
- **Infrastructure only**: You must separately deploy and configure the security appliances

### Additional AWS Network Firewall Options
```hcl
# Allow all traffic through AWS Network Firewall (for testing)
aws_network_firewall_allow_all = true
```

## Usage
1. Update account IDs in the YAML files and define VPCs as you wish
2. Configure your AWS profiles
3. Run:
   ```bash
   tofu init
   tofu plan
   tofu apply
   ```
