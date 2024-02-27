resource "google_compute_network" "vpc" {
  name                    = var.name
  project                 = var.project
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "subnet" {
  count         = length(var.subnets)
  name          = var.subnets[count.index]["name"]
  ip_cidr_range = var.subnets[count.index]["cidr"]
  region        = var.region
  project       = var.project
  network       = google_compute_network.vpc.self_link
  depends_on    = [google_compute_network.vpc]
  private_ip_google_access = true
  # private_ip_google_access = (count.index == 1) ? 1 : 0

}

resource "google_compute_route" "default_route" {
  count            = var.internet_gateway ? 1 : 0
  name             = "default-route-to-internet-${var.name}"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.vpc.self_link
  next_hop_gateway = "default-internet-gateway"
  priority         = 10000
  depends_on       = [google_compute_network.vpc]
}


resource "google_compute_instance" "compute-csye6225" {
  boot_disk {
    device_name = "compute-csye6225"

    initialize_params {
      image = "projects/tf-project-csye-6225/global/images/custom-image-with-mysql"
      size  = 100
      type  = "pd-balanced"
    }

    mode = "READ_WRITE"
  }

  machine_type = "e2-standard-4"
  name         = "compute-csye6225"
  project      = var.project

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }
    subnetwork = google_compute_subnetwork.subnet[0].self_link
  }
  service_account {
    email  = "csye6225-service-for-packer@tf-project-csye-6225.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  zone = "us-east1-b"
  depends_on = [google_compute_subnetwork.subnet[0]]
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc.self_link
  project = var.project

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = ["0.0.0.0/0"] 
  depends_on = [google_compute_network.vpc]
}

resource "google_compute_firewall" "deny_ssh" {
  name    = "deny-ssh"
  network = google_compute_network.vpc.self_link
  project = var.project

  deny {
    protocol = "tcp"
    ports    = ["22"] 
  }

  source_ranges = ["0.0.0.0/0"]
  depends_on = [google_compute_network.vpc]
}


resource "google_compute_global_address" "default" {
  project      = var.project
  name         = "private-google-access-ip"
  address_type = "INTERNAL"
  purpose      = "VPC_PEERING"
  prefix_length = 24
  network      = google_compute_network.vpc.id
  depends_on = [google_compute_network.vpc]
}
 
 
resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.default.name]
  depends_on = [google_compute_network.vpc]
}
 
resource "google_sql_database_instance" "db_instance_2" {
  name             = "db-instance-2"
  database_version = "MYSQL_8_0"
  region           = var.region

  settings {
    tier = "db-n1-standard-1"

    ip_configuration {
      ipv4_enabled = false 
      private_network = google_compute_network.vpc.self_link
    }
  }
  deletion_protection = false
  depends_on = [google_service_networking_connection.default]
}

resource "google_sql_database" "mysql_db_1" {
  name     = "mysql_db_1"
  instance = google_sql_database_instance.db_instance_2.name 
  depends_on = [google_sql_database_instance.db_instance_2]
}

resource "google_sql_user" "mysql_user_1" {
  name     = "mysql_user_1"
  instance = google_sql_database_instance.db_instance_2.name 
  password = "1234@Data" 
  depends_on = [google_sql_database_instance.db_instance_2]
}
