/*
Creates a Google compute network without any subnets
enables cloud NAT for all subnets
and enables firewall rues for IAP and health check ranges
*/


resource "google_compute_network" "this" {
  name                     = var.network_name
  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = true
}

resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  network = google_compute_network.this.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-router"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  endpoint_types = ["ENDPOINT_TYPE_MANAGED_PROXY_LB", "ENDPOINT_TYPE_VM", "ENDPOINT_TYPE_SWG"]

  log_config {
    enable = true
    filter = "ALL"
  }
}

# allow all access from health check ranges
resource "google_compute_firewall" "hc" {
  name          = "${var.network_name}-hc"
  direction     = "INGRESS"
  network       = google_compute_network.this.id
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  priority      = 1000
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  target_tags = [] # apply to all instances in the VPC
}

# allow all access from IAP ranges
resource "google_compute_firewall" "iap" {
  name          = "${var.network_name}-iap"
  direction     = "INGRESS"
  network       = google_compute_network.this.id
  source_ranges = ["35.235.240.0/20"]
  priority      = 1001
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = [] # apply to all instances in the VPC
}