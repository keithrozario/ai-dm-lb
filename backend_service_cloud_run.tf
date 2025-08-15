#######
# Creates a cloud run instance, by building a docker container
# in cloud_run_container folder and then deploys it to cloud run
# Creates a Serverless NEG, and two backends (one regional, one global)
# Enables all_user auth on CloudRun, but only internal traffic
#######


variable image_name {
    type = string
    default = "ai-dm-test"
}

data "google_compute_default_service_account" "default" {
  project = var.project_id
}

# gcloud build usese these credentials
resource "google_project_iam_member" "member-role" {
  for_each = toset([
    "roles/storage.objectViewer",
    "roles/storage.objectCreator",
    "roles/logging.logWriter",
    "roles/artifactregistry.writer"
  ])
  role = each.key
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
  project = var.project_id
}

## Because we use local-exec to make the deployment easier
## BUT please ensure the project id of gcloud is set to var.project_id
## gcloud config set project <var.project_id> && \
## gcloud auth application-default set-quota-project <var.project_id>
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = "${var.stack_name}-cloudrun-app"
  description   = "Cloudrun Repository for ${var.stack_name}"
  format        = "DOCKER"

  provisioner "local-exec" {
    command = "gcloud builds submit --tag ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.name}/${var.image_name}"
    working_dir = "./cloud_run_container"
  }
}

output registry_name {
    value = google_artifact_registry_repository.docker_repo.name
}

data "google_artifact_registry_docker_image" "cloud_run_image" {
  depends_on    = [google_artifact_registry_repository.docker_repo]
  location      = google_artifact_registry_repository.docker_repo.location
  repository_id = google_artifact_registry_repository.docker_repo.repository_id
  image_name    = var.image_name
}

resource "google_cloud_run_v2_service" "default" {
  name     = "${var.stack_name}-cloudrun-service"
  location = var.region
  deletion_protection = false
  # Allow external load balancer access
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    containers {
      image = data.google_artifact_registry_docker_image.cloud_run_image.self_link
      ports {
        container_port = 8080
      }
    }

  }
}

resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  provider              = google-beta
  name                  = "serverless-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_v2_service.default.name
  }
}

resource "google_compute_backend_service" "cloudrun" {
  name                            = "${var.stack_name}-cloudrun-service"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  backend {
    group = google_compute_region_network_endpoint_group.serverless_neg.id
  }
}

resource "google_compute_region_backend_service" "cloudrun_regional" {
  name                            = "${var.stack_name}-cloudrun-service-regional"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  backend {
    capacity_scaler = 1.0
    balancing_mode  = "UTILIZATION"
    group = google_compute_region_network_endpoint_group.serverless_neg.id
  }
}

#  Not permitted in Argolis
resource "google_cloud_run_service_iam_binding" "default" {
  location = google_cloud_run_v2_service.default.location
  service  = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  ## Unauthenticated users are not allowed by default
  ## to allow, log in as an Org Admin
  ## Go to IAM -> Org Policies
  ## Search for Domain Restricted Sharing and set to "Allow All"
  members = [
    "allUsers"
  ]
}