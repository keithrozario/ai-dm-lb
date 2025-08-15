## Install agent ops policy for all instances in the region
## https://github.com/terraform-google-modules/terraform-google-cloud-operations/blob/main/examples/ops_agent_policy_install_all_in_region/main.tf

data "google_compute_zones" "available" {
  region = var.region
}

resource "google_project_service" "osconfig" {
  service = "osconfig.googleapis.com"
  disable_on_destroy = false
}

module "ops_agent_policy" {
  depends_on = [ google_project_service.osconfig ]
  for_each        = toset(data.google_compute_zones.available.names)

  source          = "github.com/terraform-google-modules/terraform-google-cloud-operations/modules/ops-agent-policy"
  zone            = each.key
  assignment_id   = "${var.mig_name}-ops-agent-policy-${each.key}"
  agents_rule = {
    type = "ops-agent"
    enable-autoupgrade = "true"
    package_state = "installed"
    version = "latest"
  }
  instance_filter = { all = true }
}