resource "google_compute_backend_service" "default" {
  project = var.google_project

  name = "${var.service_name}-g"
  backend {
    group = var.neg_self_link
  }
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "default" {
  project = var.google_project

  name = "${var.service_name}-l7-xlb-urlmap-g-0"

  # Accept only traffic that is addressed to the right domain name
  host_rule {
    hosts        = [join(".", [var.service_name, var.domain])]
    path_matcher = "default"
  }

  # Our service will handle all trafic that is addressed right
  path_matcher {
    name            = "default"
    default_service = google_compute_backend_service.default.id
    default_route_action {
      fault_injection_policy {
        abort {
          http_status = 500
          percentage  = var.simulate_failure ? 100 : 0
        }
      }
    }
  }

  # Drop the traffic not addressed to our service (wrong host)
  default_service = google_compute_backend_service.default.id
  default_route_action {
    fault_injection_policy {
      abort {
        http_status = 404
        percentage  = 100
      }
    }
  }
}

resource "google_compute_ssl_policy" "modern" {
  project = var.google_project

  name            = "modern-ssl-policy-g"
  description     = "The SSL policy for Load Balancer Failover Demo."
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_certificate_manager_certificate_map" "default" {
  project = var.google_project

  name        = "${var.service_name}-certmap-g-0"
  description = "Maps Google-managed certificates to the Dummy Service domain name for the Load Balancer Failover Demo"
}

resource "google_certificate_manager_certificate_map_entry" "default" {
  project = var.google_project

  name     = "${var.service_name}-certmapentry-g-0"
  map      = google_certificate_manager_certificate_map.default.name
  hostname = join(".", [var.service_name, var.domain])

  # FIXME no data resource exists for managed certificates from Certificate Manager
  certificates = [
    var.certificate_manager_certificate,
  ]
}

resource "google_compute_target_https_proxy" "default" {
  project = var.google_project

  name            = "${var.service_name}-https-tgtproxy-g"
  url_map         = google_compute_url_map.default.id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.default.id}"
  ssl_policy      = google_compute_ssl_policy.modern.self_link
}

resource "google_compute_global_address" "default" {
  project = var.google_project

  name         = "${var.service_name}-l7-xlb-g"
  address_type = "EXTERNAL"
}

resource "google_compute_global_forwarding_rule" "default" {
  project = var.google_project

  name                  = "${var.service_name}-l7-xlb-fwrule-g-0"
  target                = google_compute_target_https_proxy.default.self_link
  ip_address            = google_compute_global_address.default.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

data "aws_route53_zone" "default" {
  name         = var.domain
  private_zone = false
}

resource "aws_route53_health_check" "default" {
  fqdn             = join(".", [var.service_name, var.domain])
  ip_address       = google_compute_global_address.default.address
  port             = 443
  request_interval = 30
  tags = {
    "Name" : var.service_name
  }
  type = "HTTPS"
}

resource "aws_route53_record" "lb_https_global" {
  zone_id = data.aws_route53_zone.default.zone_id
  name    = join(".", [var.service_name, var.domain])
  type    = "A"
  ttl     = 300
  records = [
    google_compute_global_address.default.address,
  ]
  failover_routing_policy {
    type = "PRIMARY"
  }
  health_check_id = aws_route53_health_check.default.id
  set_identifier  = "global"
}
