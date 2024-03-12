variable "project_id" {
    type = string
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

variable "credentials_file" {
}
variable "vpcs" {
    description = "A map of VPC configurations."
}

variable "deletion_protection"{
  type = bool
  default = false
}
variable "availability_type" {
  type        = string
  default     = "REGIONAL"
}

variable "disk_type" {
  type        = string
  default     = "pd-ssd"
}

variable "disk_size" {
  type        = number
  default     = 100
}

variable "ipv4_enabled" {
  type        = bool
  default     = false
}

