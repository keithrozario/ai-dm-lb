#####
# Creates a global Load balancer
# routes traffic to the cloud run service
#####


resource "google_compute_global_address" "global_lb" {
  name       = "lb-ipv4-1"
  ip_version = "IPV4"
}

resource "google_compute_url_map" "redirect" {
  name            = "${var.stack_name}"
  default_service = google_compute_backend_service.cloudrun.id
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "${var.stack_name}"
  url_map = google_compute_url_map.redirect.id
}

resource "google_compute_global_forwarding_rule" "redirect" {
  name        = "${var.stack_name}"
  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.redirect.id
  ip_address            = google_compute_global_address.global_lb.id
}