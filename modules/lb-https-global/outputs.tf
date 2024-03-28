output "address_name" {
  value = google_compute_global_address.default.name
}

output "address_ipv4" {
  value = google_compute_global_address.default.address
}
