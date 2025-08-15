variable "gcp_services_to_enable" {
  description = "List of GCP APIs to enable."
  type        = list(string)
  default     = [
    "compute.googleapis.com",
    "storage.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com"
  ]
}

resource "google_project_service" "enabled_services" {
  for_each = toset(var.gcp_services_to_enable)
  project  = var.project_id
  service  = each.value
}