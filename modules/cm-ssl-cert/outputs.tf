output "certificate" {
  description = <<-EOT
    The name of the certificate resource in Certificate Manager.
    Certificate names are unique globally and follow the pattern 
    'projects/*/locations/*/certificates/*'.
  EOT

  value = google_certificate_manager_certificate.default.id
}
