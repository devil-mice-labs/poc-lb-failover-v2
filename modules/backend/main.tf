resource "google_service_account" "default" {
  account_id   = var.service_name
  display_name = "Dummy Service (Load Balancer Failover Demo)"
  project      = var.google_project
}

resource "google_cloud_run_v2_service" "default" {
  description  = "Dummy Service (Load Balancer Failover Demo)"
  ingress      = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  name         = var.service_name
  launch_stage = "GA"
  location     = var.google_region
  project      = var.google_project

  template {
    containers {
      image = var.container_image
      ports {
        name           = "http1"
        container_port = 8080
      }
      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }
      liveness_probe {
        http_get {
          http_headers {
            name  = "CloudRun-Liveness-Probe"
            value = 1
          }
        }
        period_seconds = 30
      }
      startup_probe {
        http_get {
          http_headers {
            name  = "CloudRun-Startup-Probe"
            value = 1
          }
        }
        failure_threshold     = 7
        initial_delay_seconds = 2
        period_seconds        = 5
        timeout_seconds       = 1
      }
    }
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    service_account       = google_service_account.default.email
    scaling {
      min_instance_count = 0
      max_instance_count = 4
    }
    timeout = "15s"
  }
}

# The service does not require authentication.
resource "google_cloud_run_v2_service_iam_member" "default" {
  location = google_cloud_run_v2_service.default.location
  name     = google_cloud_run_v2_service.default.name
  project  = var.google_project
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# A (serverless) NEG is not a load balancing component!
# https://cloud.google.com/load-balancing/docs/negs/serverless-neg-concepts#load_balancing_components
# Serverless NEGs are pretty much immutable - check the API docs.
resource "google_compute_region_network_endpoint_group" "default" {
  description           = "Serverless NEG for the Dummy Service (Load Balancer Failover Demo)"
  name                  = "${var.service_name}-r"
  network_endpoint_type = "SERVERLESS"
  project               = var.google_project
  region                = var.google_region

  cloud_run {
    service = google_cloud_run_v2_service.default.name
  }
}
