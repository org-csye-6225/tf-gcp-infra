resource "google_service_account" "my_service_account" {
  account_id   = "new-service-account"
  display_name = "new-service-account"
  project = var.project
}

resource "google_project_iam_binding" "logging_admin_binding" {
  project = var.project
  role    = "roles/logging.admin"
  
  members = [
    "serviceAccount:${google_service_account.my_service_account.email}"
  ]
}

resource "google_project_iam_binding" "monitoring_metric_writer_binding" {
  project = var.project
  role    = "roles/monitoring.metricWriter"
  
  members = [
    "serviceAccount:${google_service_account.my_service_account.email}"
  ]
}

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

 resource "google_sql_database_instance" "db_instance_10" {
  name             = "db-instance-10"
  database_version = "MYSQL_8_0"
  region           = var.region

  settings {
    tier = var.tier
    disk_type = var.disk_type
    disk_size = var.disk_size
    backup_configuration {
      enabled = true
      binary_log_enabled = true
    }
    availability_type = var.availability_type
     ip_configuration {
      ipv4_enabled = var.ipv4_enabled 
      private_network = google_compute_network.vpc.self_link
    }
  }
  deletion_protection = var.deletion_protection
  depends_on = [google_service_networking_connection.default]
}
resource "google_sql_database" "mysql_db_1" {
  name     = "webapp"
  instance = google_sql_database_instance.db_instance_10.name 
  depends_on = [google_sql_database_instance.db_instance_10]
}

resource "google_sql_user" "mysql_user_1" {
  name     = "webapp"
  instance = google_sql_database_instance.db_instance_10.name 
  password = random_string.database_pswd.result 
  depends_on = [google_sql_database_instance.db_instance_10]
}

resource "random_string" "database_pswd" {
  length = 16
  upper = true
  lower = true
  numeric = true
  special = false
}

resource "random_string" "auth_pswd" {
  length = 16
  upper = true
  lower = true
  numeric = true
  special = false
}

resource "google_compute_instance" "compute-csye6225" {
  boot_disk {
    device_name = "compute-csye6225"

    initialize_params {
      image = "projects/tf-project-csye-6225/global/images/custom-image-with-mysql-1710656283"
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
 metadata = {
  startup-script = <<-EOT
    #!/bin/bash
    cat <<EOF >> /opt/csye6225/webapp/.env
    DATABASE=webapp
    SQL_USER=webapp
    SQL_PSWD=${random_string.database_pswd.result}
    AUTH_USER=test@test.com
    AUTH_PSWD=${random_string.auth_pswd.result}
    HOST=${google_sql_database_instance.db_instance_10.private_ip_address}
    EOF
    chown csye6225:csye6225 /opt/csye6225/webapp/.env

    # Create or update config.yaml
    cat <<EOF > /etc/google-cloud-ops-agent/config.yaml
    logging:
      receivers:
        my-app-receiver:
          type: files
          include_paths:
            - /var/log/webapp/combined.log
          record_log_file_path: true
      processors:
        my-app-processor:
          type: parse_json
          time_key: time
          time_format: "%Y-%m-%dT%H:%M:%S.%L%Z"
      service:
        pipelines:
          default_pipeline:
            receivers: [my-app-receiver]
            processors: [my-app-processor]
    EOF

    # Restart google-cloud-ops-agent service
    sudo systemctl restart google-cloud-ops-agent
  EOT
}

  service_account {
       email  = google_service_account.my_service_account.email
       scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  zone = "us-east1-b"
  depends_on = [
    google_sql_database_instance.db_instance_10,
    google_service_account.my_service_account,
    google_project_iam_binding.logging_admin_binding,
    google_project_iam_binding.monitoring_metric_writer_binding
  ]
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
