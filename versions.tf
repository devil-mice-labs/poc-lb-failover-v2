terraform {
  required_version = ">= 1.4.6, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.42.0"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.4.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.21.0"
    }
  }
}
