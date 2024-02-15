variable "project_id" {
    default = "tf-project-csye-6225"
    type = string
}
variable "region_id" {
    default = "us-east1"
    type = string
}
variable "vpc_name" {
    default = "vpc-csye6225"
    type = string
}
variable "vpc_routing_mode" {
    default = "REGIONAL"
    type = string
}
variable "private_subnet" {
    default = "database"
    type = string
}
variable "public_subnet" {
    default = "webapp"
    type = string
}

variable "vpcs" {
    description = "A map of VPC configurations."
    default = {
        vpc1 = {
            name         = "vpc-csye6225"
            routing_mode = "REGIONAL"
            subnets = [
                { name = "webapp", cidr = "10.0.0.0/24" },
                { name = "database", cidr = "10.1.0.0/24" }
      ]
    }    
  }
}
