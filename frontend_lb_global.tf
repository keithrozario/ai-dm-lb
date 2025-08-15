#######
# Creates a Global Load Balancer
# Backed with an internet NEG
# NEG will point to a IP of another load balancer (or anything else)
#######


locals {
  global_lb_destination_ip = google_compute_global_address.global_lb.address
}

## For Argolis doesn't allow this by default
## Disable Internet Network Endpoint Groups in th Org Policy

#### GLobal Load Balancer NEG
resource "google_compute_global_network_endpoint_group" "internet_neg" {
  name                = "internet-neg"
  network_endpoint_type = "INTERNET_IP_PORT"
  description         = "Internet NEG to serve ALB backend"
}

resource "google_compute_global_network_endpoint" "external_endpoint" {
  global_network_endpoint_group = google_compute_global_network_endpoint_group.internet_neg.name
  ip_address                    = google_compute_global_address.global_lb.address
  port                          = 80

}

resource "google_compute_backend_service" "load_balancer" {
  name                            = "${var.stack_name}-lb-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  backend {
    group = google_compute_global_network_endpoint_group.internet_neg.id
  }
}

### Regional Load Balancer NEG
resource "google_compute_global_network_endpoint_group" "regional_lb_neg" {
  name                = "internet-neg-regional-lb"
  network_endpoint_type = "INTERNET_IP_PORT"
  description         = "Internet NEG to serve regional ALB backend"
}

resource "google_compute_global_network_endpoint" "regional_lb_endpoint" {
  global_network_endpoint_group = google_compute_global_network_endpoint_group.regional_lb_neg.name
  ip_address                    = local.global_lb_destination_ip
  port                          = 80
}

resource "google_compute_backend_service" "load_balancer_regional" {
  name                            = "${var.stack_name}-relb-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  backend {
    group = google_compute_global_network_endpoint_group.regional_lb_neg.id
  }
}

resource "google_compute_url_map" "lb-map" {
  name            = "lb-map"
  default_service = google_compute_backend_service.load_balancer_regional.id
}

resource "google_compute_target_http_proxy" "lb-proxy" {
  name    = "${var.stack_name}-lb-proxy"
  url_map = google_compute_url_map.lb-map.id
}

resource "google_compute_global_address" "first_lb" {
  name       = "lb-ipv4-first-lb"
  ip_version = "IPV4"
}

resource "google_compute_global_forwarding_rule" "lb-to-lb" {
  name        = "${var.stack_name}-lb-to-lb"
  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.lb-proxy.id
  ip_address            = google_compute_global_address.first_lb.id
}

output frontend_global_lb_ip {
  value = google_compute_global_address.first_lb.address
}
