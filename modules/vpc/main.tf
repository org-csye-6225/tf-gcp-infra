resource "google_compute_network" "vpc" {
  name                    = var.name
  project                 = var.project
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
}

resource "google_compute_subnetwork" "subnet" {
  count         = length(var.subnets)
  name          = var.subnets[count.index]["name"]
  ip_cidr_range = var.subnets[count.index]["cidr"]
  region        = var.region
  project       = var.project
  network       = google_compute_network.vpc.id
  depends_on    = [google_compute_network.vpc]


resource "google_compute_route" "default_route" {
  count            = var.internet_gateway ? 1 : 0
  name             = "default-route-to-internet-${var.name}"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.vpc.id
  next_hop_gateway = "default-internet-gateway"
  depends_on       = [google_compute_network.vpc]
}
