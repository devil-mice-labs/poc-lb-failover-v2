variable "google_project" {
  type     = string
  nullable = false
}

variable "google_region" {
  type     = string
  nullable = false
}

variable "domain" {
  type     = string
  nullable = false
}

variable "service_name" {
  type     = string
  nullable = false
}

variable "neg_self_link" {
  description = "Identifies the network endpoint group to add to the load balancer's backend service."
  nullable    = false
  type        = string
}

variable "certificate_manager_certificate" {
  description = "The TLS certificate resource must be 'global' in scope."
  nullable    = false
  type        = string
}

variable "simulate_failure" {
  nullable = false
  type     = bool
}
