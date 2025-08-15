######
# Creates a front-end regional load balancer
# That routes traffic to another regional load balancer
# via a Internet NEG
# There is a requirement that CloudNAT be deployed in the LB VPC to allow external traffic
# view more info in module.vpc.google_compute_router_nat.nat for more info.
######

locals {
  regional_lb_destination_ip = google_compute_address.regional_lb.address
}

## For Argolis doesn't allow this by default
## Disable Internet Network Endpoint Groups in th Org Policy
resource "google_compute_region_network_endpoint_group" "internet_neg" {
  name                  = "region-ip-neg"
  region                = "asia-southeast1"
  network               = module.vpc.network_id
  network_endpoint_type = "INTERNET_IP_PORT"
}

resource "google_compute_region_network_endpoint" "external_endpoint" {
    region_network_endpoint_group = google_compute_region_network_endpoint_group.internet_neg.id
    port = 80
    ip_address = local.regional_lb_destination_ip
    region = "asia-southeast1"
}   

resource "google_compute_region_backend_service" "load_balancer" {
  name                            = "${var.stack_name}-regional-lb-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  backend {
    capacity_scaler = 1.0
    balancing_mode  = "UTILIZATION"
    group = google_compute_region_network_endpoint_group.internet_neg.id
  }
}

resource "google_compute_region_url_map" "lb-map-regional" {
  name            = "lb-map-regional"
  default_service = google_compute_region_backend_service.load_balancer.id
}

resource "google_compute_region_target_http_proxy" "lb-proxy" {
  name    = "${var.stack_name}-lb-proxy-regional"
  url_map = google_compute_region_url_map.lb-map-regional.id
}

resource "google_compute_address" "first_regional_lb" {
  name         = "first-regional-lb"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  region       = data.google_client_config.this.region
}

resource "google_compute_forwarding_rule" "lb-to-lb" {
  name        = "${var.stack_name}-lb-to-lb"
  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.lb-proxy.id
  ip_address            = google_compute_address.first_regional_lb.id
  network               = module.vpc.network_id
  network_tier          = "PREMIUM"
}

output frontend_regional_lb_ip {  
  value = google_compute_address.first_regional_lb.address
}
