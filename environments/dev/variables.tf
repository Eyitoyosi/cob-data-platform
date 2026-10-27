variable "environment" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to deploy into"
}