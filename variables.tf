variable "aws_region" {
  description = <<-EOT
    AWS region where the AWS provider will operate. This setting is
    required by the AWS provider even though we only deploy "global" 
    resources so it has a sensible default value and can be ignored.
  EOT
  type        = string
  nullable    = false
  default     = "us-east-1"
}

variable "google_project" {
  description = <<-EOT
    The Google Cloud project ID for the project to manage the resources in. 
    This project must already exist and you should have appropriate 
    IAM roles assigned.
  EOT
  type        = string
  nullable    = false
}

variable "google_region" {
  description = <<-EOT
    The Google Cloud region to manage the (regional) resources in.
  EOT
  type        = string
  nullable    = false
}

variable "domain" {
  description = <<-EOT
    Public DNS domain name to use. The zone must be hosted in Amazon Route 53.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = !endswith(var.domain, ".")
    error_message = "Must not end with a dot."
  }
}

variable "service_name" {
  description = <<-EOT
    A creative name for the Dummy Service. Must be unique and available within the domain.
    A sensible default is provided.
  EOT
  type        = string
  nullable    = false
  default     = "pony-express"

  validation {
    condition     = length(regexall("^[a-z](?:[-a-z0-9]*[a-z0-9])$", var.service_name)) > 0
    error_message = "Must comply with RFC1035: lowercase letters, digits, and dashes only."
  }
  validation {
    condition     = length(var.service_name) >= 6 && length(var.service_name) <= 15
    error_message = "Must be between 6 and 15 characters long."
  }
}

variable "simulate_failure" {
  description = <<-EOT
    Controls simulated fault of the Global External Application Load Balancer.
    When set to 'true', the fault injection feature is enabled on the load balancer,
    resulting in errors when servicing requests. Set to 'false' to return to the normal
    operating mode.
  EOT
  type        = bool
  nullable    = false
}
