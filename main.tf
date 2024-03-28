# Global-to-Regional External Application Load Balancer failover on Google Cloud (Mark 2)
# Docs are in README.md
# Configurable parameters are in terraform.tfvars

# TODO add common labels at the AWS provider level
# TODO add common labels at the Google provider level
# TODO validate Google Cloud API enablement
# TODO rename backend module to dummy-service
# TODO review NEG and lb backend resources placement

provider "aws" {
  region = var.aws_region
}

provider "google" {
  project                         = var.google_project
  region                          = "global"
  add_terraform_attribution_label = true
}

# Validate AWS region name
data "aws_region" "default" {
  name = var.aws_region
}

# Validate that the target Google Cloud project exists
data "google_project" "default" {
  project_id = var.google_project
}

# Validate Google Cloud region name
data "google_compute_regions" "available" {
  project = data.google_project.default.project_id
  status  = "UP"

  lifecycle {
    postcondition {
      condition     = contains(self.names, var.google_region)
      error_message = "Must be a valid Google Cloud region that is currently active and available."
    }
  }
}

# Validate the domain
data "dns_ns_record_set" "domain" {
  host = var.domain

  lifecycle {
    postcondition {
      condition     = length(self.nameservers) > 0
      error_message = "Public DNS zone must exist for the domain."
    }
  }
}

# The dummy service that is to be exposed to the public Internet via the load balancers. 
# This service is not directly accessible from public IP addresses.
module "backend" {
  source     = "./modules/backend"
  depends_on = [data.google_compute_regions.available]

  google_project = data.google_project.default.project_id
  google_region  = var.google_region
  service_name   = var.service_name
}

# A global Google-managed TLS certificate with DNS authorization.
# These resources have a global scope.
module "global_certificate_manager_ssl_certificate" {
  source = "./modules/cm-ssl-cert"

  google_project = data.google_project.default.project_id
  domain         = data.dns_ns_record_set.domain.host
  service_name   = var.service_name
}

# A global External Application Load Balancer. HTTPS only.
# Some components of the global LB are regional by design.
module "global_application_load_balancer" {
  source     = "./modules/lb-https-global"
  depends_on = [data.google_compute_regions.available]

  google_project                  = data.google_project.default.project_id
  google_region                   = var.google_region
  certificate_manager_certificate = module.global_certificate_manager_ssl_certificate.certificate
  domain                          = data.dns_ns_record_set.domain.host
  service_name                    = var.service_name
  neg_self_link                   = module.backend.neg_self_link
  simulate_failure                = var.simulate_failure
}

# A regional Google-managed TLS certificate with DNS authorization.
# These resources are regional in scope.
module "regional_certificate_manager_ssl_certificate" {
  source     = "./modules/cm-ssl-cert"
  depends_on = [data.google_compute_regions.available]

  google_project = data.google_project.default.project_id
  google_region  = var.google_region
  domain         = data.dns_ns_record_set.domain.host
  service_name   = var.service_name
}

# A regional External Application Load Balancer. HTTPS only.
module "regional_application_load_balancer" {
  source     = "./modules/lb-https-regional"
  depends_on = [data.google_compute_regions.available]

  google_project                  = data.google_project.default.project_id
  google_region                   = var.google_region
  certificate_manager_certificate = module.regional_certificate_manager_ssl_certificate.certificate
  domain                          = data.dns_ns_record_set.domain.host
  service_name                    = var.service_name
  neg_self_link                   = module.backend.neg_self_link
}
