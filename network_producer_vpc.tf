module vpc {
    source = "./vpc"
    network_name = "${var.stack_name}-vpc"
    region = var.region
}



# module tls_cert {
#     source = "./tls_cert"
#     subdomain = var.stack_name
#     description = "${var.stack_name} TLS Certificate"
# }


# module "dns_record"{
#   source = "./domain_entry"
#   subdomain = var.stack_name
#   rrdatas = [google_compute_global_address.global_lb.address]
#   description = var.stack_name
# }

