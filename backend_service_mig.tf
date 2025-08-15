######
# Creates a Managed instance group that host a simple web server
# all instances deployed into a single subnet (single region)
######

resource "google_compute_subnetwork" "vm_instances" {
  name             = "${var.stack_name}-vm-instances"
  ip_cidr_range    = "10.0.1.0/24"
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "EXTERNAL"
  region           = var.region
  network          = module.vpc.network_id
}

module regional_mig {
    source = "./regional-mig"
    mig_name = "${var.stack_name}-mig"
    network_id = module.vpc.network_id
    subnetwork_id = google_compute_subnetwork.vm_instances.id
    region = var.region
}

resource "google_compute_subnetwork" "vm_instances_psc_network" {
  name             = "${var.stack_name}-vm-instances-psc-network"
  ip_cidr_range    = "10.0.1.0/24"
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "EXTERNAL"
  region           = var.region
  network          = module.vpc_psc.network_id
}

module regional_mig_psc_network {
    source = "./regional-mig"
    mig_name = "${var.stack_name}-mig-in"
    network_id = module.vpc_psc.network_id
    subnetwork_id = google_compute_subnetwork.vm_instances_psc_network.id
    region = var.region
}