variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the web server will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the EC2 instances"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access (optional)"
  type        = string
  default     = null
}

variable "admin_username" {
  description = "Username for the admin user to be created on the EC2 instance"
  type        = string
  default     = "admin"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{0,31}$", var.admin_username))
    error_message = "Username must start with a lowercase letter, contain only lowercase letters, numbers, hyphens, and underscores, and be 32 characters or less."
  }
}

variable "create_nlb" {
  description = "Whether to create the Network Load Balancer and associated resources"
  type        = bool
  default     = true
}
