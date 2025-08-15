######
# Creates an internal regional load balancer
# THat connects tot he mig backend
# and creates a service attachement for the PSC purposes
#####

resource "google_compute_subnetwork" "internal_lb_subnet" {
  name          = "internal-load-balancer"
  ip_cidr_range = "10.0.4.0/24"
  network       = module.vpc.network_id
  region        = var.region
  role          = "ACTIVE"
}

resource "google_compute_region_backend_service" "regional_lb_internal" {
  name                  = "l7-xlb-backend-service-internal"
  region                = var.region
  port_name             = "http-port"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.regional_lb.id]
  protocol              = "HTTP"
  session_affinity      = "NONE"
  timeout_sec           = 30
  backend {
    group           = module.regional_mig.instance_group_manager
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_url_map" "regional_lb_internal" {
  name            = "regional-l7-xlb-map-internal"
  region          = var.region
  default_service = google_compute_region_backend_service.regional_lb_internal.id
}

resource "google_compute_region_target_http_proxy" "regional_lb_internal" {
  name    = "regional-xlb-proxy-internal"
  region  = var.region
  url_map = google_compute_region_url_map.regional_lb_internal.id
}

resource "google_compute_forwarding_rule" "regional_lb_internal" {
  name       = "regional-l7-xlb-forwarding-rule-psc"
  depends_on = [google_compute_subnetwork.proxy_only]
  region     = var.region

  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.regional_lb_internal.id
  network               = module.vpc.network_id
  subnetwork = google_compute_subnetwork.internal_lb_subnet.id
  network_tier          = "PREMIUM"
}

resource "google_compute_subnetwork" "nat_for_psc" {
  name          = "nat-for-psc"
  ip_cidr_range = "10.0.3.0/24"
  network       = module.vpc.network_id
  region        = var.region
  role          = "ACTIVE"
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

resource "google_compute_service_attachment" "psc_ilb_service_attachment" {
  name        = "ai-dm-service-attachment"
  region      = "asia-southeast1"
  description = "A service attachment configured to the regional load balancer"

  enable_proxy_protocol    = false
  connection_preference    = "ACCEPT_AUTOMATIC"
  nat_subnets              = [google_compute_subnetwork.nat_for_psc.id]
  target_service           = google_compute_forwarding_rule.regional_lb_internal.id
}