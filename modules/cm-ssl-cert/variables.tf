variable "google_project" {
  type     = string
  nullable = false
}

variable "google_region" {
  type     = string
  nullable = false
  default  = "global"
}

variable "domain" {
  type     = string
  nullable = false
}

variable "service_name" {
  type     = string
  nullable = false
}
