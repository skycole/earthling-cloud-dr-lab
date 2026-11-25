variable "aws_region" {
  description = "AWS region for the lab (default us-east-1)."
  type        = string
  default     = "us-east-1"
}

variable "budget_notification_email" {
  description = "Email address for AWS Budget alerts."
  type        = string
  default     = "alerts@example.com"
}

variable "lab_name_prefix" {
  description = "Short prefix for globally unique resource names."
  type        = string
  default     = "earthling-dr"
}