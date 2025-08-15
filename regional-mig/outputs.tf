output backend_service_id {
    value = google_compute_backend_service.this.id
    description = "ID of the backend service created for the MIG"
}

output health_check_id{
    value = google_compute_health_check.this.id
    description = "ID of the health check created for the MIG"
}

output instance_group_manager{
    value = google_compute_region_instance_group_manager.this.instance_group
    description = "ID of the instance group manager created for the MIG"
}