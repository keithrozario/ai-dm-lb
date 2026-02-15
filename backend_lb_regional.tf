###
# Creates a Regional Load Balancer with a Regional Mig as backend
###

resource "google_compute_subnetwork" "proxy_only" {
  name          = "proxy-only-subnet"
  ip_cidr_range = "10.0.2.0/24"
  network       = module.vpc.network_id
  region        = data.google_client_config.this.region
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_firewall" "allow_proxy" {
  name = "fw-allow-proxies"
  allow {
    ports    = ["443"]
    protocol = "tcp"
  }
  allow {
    ports    = ["80"]
    protocol = "tcp"
  }
  allow {
    ports    = ["8080"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = module.vpc.network_id
  priority      = 1000
  source_ranges = [google_compute_subnetwork.proxy_only.ip_cidr_range]
  target_tags   = []  # apply to all instances
}

resource "google_compute_address" "regional_lb" {
  name         = "regional-lb"
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
  region       = data.google_client_config.this.region
}

resource "google_compute_region_health_check" "regional_lb" {
  name               = "regional-lb-healthcheck"
  check_interval_sec = 5
  healthy_threshold  = 2
  http_health_check {
    port_specification = "USE_SERVING_PORT"
    proxy_header       = "NONE"
    request_path       = "/"
  }
  region              = data.google_client_config.this.region
  timeout_sec         = 5
  unhealthy_threshold = 2
}

resource "google_compute_region_backend_service" "regional_lb" {
  name                  = "l7-xlb-backend-service"
  region                = data.google_client_config.this.region
  port_name             = "http-port"
  load_balancing_scheme = "EXTERNAL_MANAGED"
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

resource "google_compute_region_url_map" "regional_lb" {
  name            = "regional-l7-xlb-map"
  region          = data.google_client_config.this.region
  default_service = google_compute_region_backend_service.regional_lb.id
}

resource "google_compute_region_target_http_proxy" "regional_lb" {
  name    = "regional-xlb-proxy"
  region  = data.google_client_config.this.region
  url_map = google_compute_region_url_map.regional_lb.id
  
}

resource "google_compute_forwarding_rule" "regional_lb" {
  name       = "regional-l7-xlb-forwarding-rule"
  depends_on = [google_compute_subnetwork.proxy_only]
  region     = data.google_client_config.this.region

  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.regional_lb.id
  network               = module.vpc.network_id
  ip_address            = google_compute_address.regional_lb.id
  network_tier          = "STANDARD"
}


output regional_lb_ipv4_http {
    value = google_compute_address.regional_lb.address
}



