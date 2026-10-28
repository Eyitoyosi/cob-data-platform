variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "github_owner" {
  type        = string
  default     = "Eyitoyosi"
  description = "GitHub user or org. Case-sensitive: it must match the repo URL exactly."
}

variable "github_repo" {
  type    = string
  default = "cob-data-platform"
}

variable "environments" {
  type        = list(string)
  default     = ["dev"]
  description = "Environments that get a plan role and an apply role"

  validation {
    condition     = alltrue([for e in var.environments : contains(["dev", "prod"], e)])
    error_message = "environments may only contain: dev, prod."
  }
}

variable "state_bucket" {
  type    = string
  default = "beejan-cob-terraform-main-state"
}

variable "lock_table" {
  type    = string
  default = "cob-terraform-locks"
}

variable "data_lake_name" {
  type        = string
  default     = "beejan-lake"
  description = "The project name used in main.tf's locals; it feeds resource names"
}