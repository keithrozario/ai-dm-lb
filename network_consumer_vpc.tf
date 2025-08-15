module vpc_psc {
    source = "./vpc"
    network_name = "${var.stack_name}-internal-vpc"
    region = var.region
}

resource "google_compute_subnetwork" "psc_endpoint_subnet" {
  name          = "psc-endpoint-subnet"
  ip_cidr_range = "10.0.100.0/24"
  network       = module.vpc_psc.network_id
  region        = var.region
  role          = "ACTIVE"
}

resource google_compute_address "internal_ip_psc_internal" {
    name = "psc-internal"
    region = var.region
    subnetwork = google_compute_subnetwork.psc_endpoint_subnet.id
    ip_version = "IPV4"
    address_type = "INTERNAL"
}

resource "google_compute_forwarding_rule" "psc_endpoint" {
  name                    = "psc-endpoint"
  region                  = "asia-southeast1"
  load_balancing_scheme   = ""
  target                  = google_compute_service_attachment.psc_ilb_service_attachment.id
  network                 = module.vpc_psc.network_id
  ip_address              = google_compute_address.internal_ip_psc_internal.id
  allow_psc_global_access = false
}