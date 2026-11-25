variable "location" {
  description = "Azure region for the lab."
  type        = string
  default     = "eastus"
}

variable "budget_notification_email" {
  description = "Email for Azure Cost Management budget alerts."
  type        = string
  default     = "alerts@example.com"
}

variable "lab_name_prefix" {
  description = "Prefix for lab resource names."
  type        = string
  default     = "earthlingdr"
}