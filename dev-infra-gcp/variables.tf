variable "project_id" {
    type = string
}
variable "credentials_file" {
}


variable "region_id" {
    type = string
}
variable "vpc_name" {
    type = string
}
variable "vpc_routing_mode" {
    type = string
}
variable "private_subnet" {
    type = string
}
variable "public_subnet" {
    type = string
}

variable "vpcs" {
    description = "A map of VPC configurations."
}
