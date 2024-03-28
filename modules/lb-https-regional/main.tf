# This module provisions a regional external HTTPS load balancer on Google Cloud.
#
# External HTTP(S) load balancer overview
# https://cloud.google.com/load-balancing/docs/https
#
# Regional external HTTP load balancers require a proxy subnet
# https://cloud.google.com/load-balancing/docs/https#proxy-only-subnet
#
# FIXME backend buckets are not supported by regional external HTTPS load balancers
# https://cloud.google.com/load-balancing/docs/url-map#configure_url_maps
#

# Backend services overview
# https://cloud.google.com/load-balancing/docs/backend-service
#
# Backend services in Google Compute Engine can be either regionally or globally scoped.
# https://cloud.google.com/compute/docs/reference/rest/v1/regionBackendServices
#
# For regional external HTTPS load balancer, the scope of backend service is "regional" ?!
# https://cloud.google.com/load-balancing/docs/backend-service
#
resource "google_compute_region_backend_service" "default" {
  project = var.google_project
  region  = var.google_region

  name = "${var.service_name}-r"
  backend {
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
    group           = var.neg_self_link
  }
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_region_url_map" "default" {
  project = var.google_project
  region  = var.google_region
  name    = "l7-xlb-${var.service_name}-urlmap-r-0"

  # Accept only traffic that is addressed to the right domain name
  host_rule {
    hosts        = [join(".", [var.service_name, var.domain])]
    path_matcher = "default"
  }

  # Our service will handle all trafic that is addressed right
  path_matcher {
    name            = "default"
    default_service = google_compute_region_backend_service.default.id
  }

  # Drop the traffic not addressed to our service (wrong host)
  default_service = google_compute_region_backend_service.default.id
  default_route_action {
    fault_injection_policy {
      abort {
        http_status = 404
        percentage  = 100
      }
    }
  }
}

resource "google_compute_region_ssl_policy" "modern" {
  project  = var.google_project
  region   = var.google_region

  name            = "modern-ssl-policy-r"
  description     = "The SSL policy for Load Balancer Failover Demo."
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

# The VPC and the proxy subnet for the load balancer.
resource "google_compute_network" "lb_net" {
  name                    = "lb-net"
  auto_create_subnetworks = false
}

resource "google_compute_region_target_https_proxy" "default" {
  project  = var.google_project
  region   = var.google_region

  name       = "${var.service_name}-target-proxy-r"
  ssl_policy = google_compute_region_ssl_policy.modern.self_link
  url_map    = google_compute_region_url_map.default.id

  certificate_manager_certificates = [
    var.certificate_manager_certificate,
  ]
}

resource "google_compute_subnetwork" "proxy_subnet" {
  project       = var.google_project
  region        = var.google_region
  network       = google_compute_network.lb_net.id
  name          = "proxy-only-subnet"
  description   = "This proxy subnet is shared between all of Envoy-based load balancers in its region. It's part of the Load Balancer Failover Demo."
  ip_cidr_range = "10.0.0.0/24"
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

# Allocate a regional external IP address.
resource "google_compute_address" "default" {
  project = var.google_project
  region  = var.google_region

  address_type = "EXTERNAL"
  name         = "${var.service_name}-l7-xlb-r"
  network_tier = "STANDARD"
  # TODO would this work with the PREMIUM network tier address?
}

resource "google_compute_forwarding_rule" "default" {
  project = var.google_project
  region  = var.google_region

  name                  = "${var.service_name}-l7-xlb-r-0"
  target                = google_compute_region_target_https_proxy.default.self_link
  ip_address            = google_compute_address.default.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "STANDARD"

  # Reference the network via the subnet to make an implicit dependency explicit.
  network = google_compute_subnetwork.proxy_subnet.network
}

data "aws_route53_zone" "default" {
  name         = var.domain
  private_zone = false
}

resource "aws_route53_record" "lb_https_regional" {
  zone_id = data.aws_route53_zone.default.zone_id
  name    = join(".", [var.service_name, var.domain])
  type    = "A"
  ttl     = 300
  records = [
    google_compute_address.default.address,
  ]
  failover_routing_policy {
    type = "SECONDARY"
  }
  set_identifier = "regional"
}
