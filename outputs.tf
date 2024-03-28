output "global_address_ipv4" {
  description = "Public IP of the Global Application Load Balancer."
  value       = module.global_application_load_balancer.address_ipv4
}

output "regional_address_ipv4" {
  description = "Public IP of the Regional Application Load Balancer."
  value       = module.regional_application_load_balancer.address_ipv4
}

output "url" {
  description = <<-EOT
    Public endpoint for the deployed service. Resolves to 
    either global or regional load balancer's IP address.
    EOT
  value = "https://${var.service_name}.${var.domain}/"
}
