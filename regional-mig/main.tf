resource "google_service_account" "this" {
  account_id   = "${var.mig_name}-service-account"
  display_name = "${var.mig_name} Service Account"
}

# instance template
resource "google_compute_instance_template" "this" {
  name         = "${var.mig_name}-instance-template"
  machine_type = "e2-micro"
  tags         = ["allow-health-check"]


  network_interface {
    network    = var.network_id
    subnetwork = var.subnetwork_id
    # This block grants a vm an external ip, can't do it in Argolis
    # access_config {
    #   # add external ip to fetch packages
    # }
  }

  labels = {
    managed-by-cnrm = "true"
  }
  region = var.region

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
  }

  # install nginx and serve a simple web page
  metadata = {
    startup-script = <<-EOF1
      #! /bin/bash
      set -euo pipefail

      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y nginx-light jq

      NAME=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/hostname")
      IP=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip")
      METADATA=$(curl -f -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/?recursive=True" | jq 'del(.["startup-script"])')

      cat <<EOF > /var/www/html/index.html
      <pre>
      Name: $NAME
      IP: $IP
      Metadata: $METADATA
      </pre>
      EOF

    EOF1
    enable-osconfig = "TRUE"
  }
  lifecycle {
    create_before_destroy = false
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.this.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform", # This grants full access to all Google Cloud APIs that the service account has been granted permissions for.
      # "https://www.googleapis.com/auth/logging.write",
      # "https://www.googleapis.com/auth/monitoring.write",
      # "https://www.googleapis.com/auth/pubsub",
      # "https://www.googleapis.com/auth/service.management.readonly",
      # "https://www.googleapis.com/auth/servicecontrol",
      # "https://www.googleapis.com/auth/trace.append"
      ]
  }
}

# Needed for VM Manager
data "google_compute_default_service_account" "default" {}
data "google_iam_policy" "admin" {
  binding {
    role = "roles/iam.serviceAccountTokenCreator"

    members = [
      "serviceAccount:${google_service_account.this.email}"
    ]
 }
 }

data "google_iam_policy" "storage" {
  binding {
    role = "roles/storage.objectViewer"

    members = [
      "serviceAccount:${google_service_account.this.email}"
    ]
  }
}

resource "google_service_account_iam_policy" "admin-account-iam" {
  service_account_id = data.google_compute_default_service_account.default.name
  policy_data        = data.google_iam_policy.admin.policy_data
}


resource "google_compute_region_instance_group_manager" "this" {
  name                             = "${var.mig_name}-group-manager"
  region                           = var.region
  distribution_policy_zones        = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]
  distribution_policy_target_shape = "BALANCED"
  base_instance_name               = "base-${var.mig_name}"
  target_size                      = var.mig_target_size

  update_policy {
    type                         = "PROACTIVE"
    minimal_action               = "REPLACE"
    instance_redistribution_type = "NONE"
    max_unavailable_fixed        = 3
  }

  named_port {
    name = "http-port"
    port = 80
  }

  version {
    instance_template = google_compute_instance_template.this.id
    name              = "primary"
  }



  auto_healing_policies {
    health_check      = google_compute_health_check.this.id
    initial_delay_sec = 300
  }
}

resource "google_compute_health_check" "this" {
  name = "${var.mig_name}-basic-health-check"

  http_health_check {
    port               = 80
    port_specification = "USE_FIXED_PORT"
    proxy_header       = "NONE"
    request_path       = "/"
  }

  check_interval_sec  = 5
  healthy_threshold   = 2
  timeout_sec         = 5
  unhealthy_threshold = 2

  log_config {
    enable = true
  }

}

resource "google_compute_backend_service" "this" {
  depends_on = [google_compute_health_check.this]
  name                            = "${var.mig_name}-backend-service-global"
  connection_draining_timeout_sec = 0
  health_checks                   = [google_compute_health_check.this.id]

  # Externally managed is the Global ALB, EXTERNAL is just classic
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_name             = "http-port"
  protocol              = "HTTP"
  session_affinity      = "NONE"
  timeout_sec           = 30
  backend {
    group           = google_compute_region_instance_group_manager.this.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
  log_config {
    enable = true
    sample_rate = 1.0
  }
}