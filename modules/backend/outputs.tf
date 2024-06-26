output "neg_self_link" {
  value = google_compute_region_network_endpoint_group.default.self_link
}

output "service_uri" {
  description = "The URL for a Cloud Run service where the Dummy Service is deployed."
  value       = google_cloud_run_v2_service.default.uri
}
