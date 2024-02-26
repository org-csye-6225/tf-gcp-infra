variable "name" {}
variable "project" {}
variable "region" {}
variable "routing_mode" {}
variable "internet_gateway" {
  default = true
}
variable "subnets" {
  type = list(object({
    name = string
    cidr = string
  }))
}
