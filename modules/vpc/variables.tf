variable "name" {}
variable "project" {}
variable "region" {}
variable "routing_mode" {}
variable "internet_gateway" {
  default = false
}
variable "subnets" {
  type = list(object({
    name = string
    cidr = string
  }))
}
