module "vpc" {
  source                  = "./modules/vpc"
  for_each                = var.vpcs
  name                    = each.value.name
  project                 = var.project_id
  region                  = var.region_id
  routing_mode            = each.value.routing_mode
  subnets                 = each.value.subnets
  credentials_file        = var.credentials_file
  internet_gateway        = true
  api_key_mailgun         = var.api_key_mailgun
  domain_key_record       = var.domain_key_record
  min_replicas            = var.min_replicas
  max_replicas            = var.max_replicas
  cpu_util                = var.cpu_util
  pathtozip               = var.pathtozip
}
