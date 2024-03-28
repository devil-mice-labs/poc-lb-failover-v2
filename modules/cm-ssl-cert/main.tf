locals {
  suffix = var.google_region == "global" ? "g" : "r"
}

resource "google_certificate_manager_dns_authorization" "default" {
  project  = var.google_project
  location = var.google_region

  name   = "${var.service_name}-dnsauth-${local.suffix}-0"
  domain = join(".", [var.service_name, var.domain])
}

resource "google_certificate_manager_certificate" "default" {
  project  = var.google_project
  location = var.google_region

  name = "${var.service_name}-cert-${local.suffix}-0"
  managed {
    dns_authorizations = [
      google_certificate_manager_dns_authorization.default.id,
    ]
    domains = [
      google_certificate_manager_dns_authorization.default.domain,
    ]
  }
}

data "aws_route53_zone" "default" {
  name         = var.domain
  private_zone = false
}

# Create the authorisation record in DNS for Google-managed SSL certificate
#   https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
resource "aws_route53_record" "dnsauth" {
  zone_id = data.aws_route53_zone.default.zone_id
  name    = google_certificate_manager_dns_authorization.default.dns_resource_record[0].name
  type    = google_certificate_manager_dns_authorization.default.dns_resource_record[0].type
  ttl     = 300
  records = [
    google_certificate_manager_dns_authorization.default.dns_resource_record[0].data,
  ]
}
