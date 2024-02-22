module "vpc" {
  source                  = "./modules/vpc"
  for_each                = var.vpcs
  name                    = each.value.name
  project                 = var.project_id
  region                  = var.region_id
  routing_mode            = each.value.routing_mode
  subnets                 = each.value.subnets
  internet_gateway        = true
}
