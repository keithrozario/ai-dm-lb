variable "stack_name" {
    type=string
    description = "Description of purpose of resources deployed here. We will prepend the stack name to most resources deployed"
    default = "ai-dm"
}

# variable "base_domain" {
#     type=string
#     default="krozario.demo.altostrat.com"
# }

variable "region" {
    type = string
    default = "asia-southeast1"
}

variable "project_id" {
    type = string
    default = "ai-dm-469100"
}