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
variable "subnets" {
  type = list(object({
    name = string
    cidr = string
  }))
}
