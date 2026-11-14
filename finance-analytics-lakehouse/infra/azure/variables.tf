variable "subscription_id" {
  description = "Azure subscription used for the portfolio deployment."
  type        = string
}

variable "location" {
  description = "Azure region for project resources."
  type        = string
  default     = "uksouth"
}

variable "environment" {
  description = "Short environment name used in resource names and tags."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,10}$", var.environment))
    error_message = "environment must contain 2-10 lowercase letters, numbers, or hyphens."
  }
}

variable "client_ip" {
  description = "Public IPv4 address allowed to connect to Synapse during deployment."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.client_ip == null || can(cidrnetmask("${var.client_ip}/32"))
    error_message = "client_ip must be a valid IPv4 address or null."
  }
}
