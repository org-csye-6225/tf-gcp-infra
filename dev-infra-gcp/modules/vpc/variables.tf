variable "name" {
   type = string
}
variable "project" {
   type = string
}
variable "region" {
   type = string
}
variable "routing_mode" { 
  type = string
}
variable "internet_gateway" {
  default = true
}
variable "credentials_file" {
}
variable "deletion_protection"{
  type = bool
  default = false
}

variable "subnets" {
  type = list(object({
    name = string
    cidr = string
  }))
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

variable "tier" {
  type        = string
  default     = "db-n1-standard-1"
}


