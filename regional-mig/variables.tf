variable "mig_name" {type=string}
variable "network_id" {type=string}
variable "subnetwork_id" {type=string}
variable "region" {type=string}
variable "mig_target_size" {
    type=number
    default=2
    description = "Target size (in instances) of the MIG"
}