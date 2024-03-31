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
      image = "projects/tf-csye-6225-project/global/images/custom-image-with-pubsub-1711567402"
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
     time_format: "%Y-%m-%dT%H:%M:%S.%fZ"
   move_severity:
     type: modify_fields
     fields:
       severity:
         move_from: jsonPayload.level
         map_values:
           INFO: "info"
           ERROR: "error"
           WARNING: "warn"
           DEBUG: "debug"
 service:
   pipelines:
     default_pipeline:
       receivers: [my-app-receiver]
       processors: [my-app-processor, move_severity]
EOF

    # Restart google-cloud-ops-agent service
    sudo systemctl restart google-cloud-ops-agent
  EOT
}

  service_account {
       email  = google_service_account.my_service_account.email
       scopes = ["https://www.googleapis.com/auth/cloud-platform", "https://www.googleapis.com/auth/pubsub"]
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


resource "google_dns_record_set" "dns_record" {
  name         = "abhinavpandey.tech."
  type         = "A"
  ttl          = 360
  managed_zone = "abhinav-csye6225"

  rrdatas = [
    google_compute_instance.compute-csye6225.network_interface[0].access_config[0].nat_ip
  ]
  depends_on = [google_compute_instance.compute-csye6225]
}
resource "google_dns_record_set" "mx_record" {
  name         = "abhinavpandey.tech."
  type         = "MX"
  ttl          = 360
  managed_zone = "abhinav-csye6225"

  rrdatas = [
    "10 mxa.mailgun.org.",
    "10 mxb.mailgun.org."
  ]
  depends_on = [google_compute_instance.compute-csye6225]
}

resource "google_dns_record_set" "txt_record" {
  name         = "abhinavpandey.tech."
  type         = "TXT"
  ttl          = 360
  managed_zone = "abhinav-csye6225"

  rrdatas = [
    "\"v=spf1 include:mailgun.org ~all\""
  ]
  depends_on = [google_compute_instance.compute-csye6225]
}

resource "google_dns_record_set" "cname_record" {
  name         = "email.abhinavpandey.tech."
  type         = "CNAME"
  ttl          = 360
  managed_zone = "abhinav-csye6225"

  rrdatas = [
    "mailgun.org."
  ]
  depends_on = [google_compute_instance.compute-csye6225]
}
resource "google_dns_record_set" "txt_domainkey_record" {
  name         = "pic._domainkey.abhinavpandey.tech."
  type         = "TXT"
  ttl          = 360
  managed_zone = "abhinav-csye6225"

  rrdatas = [
    var.domain_key_record
  ]
  depends_on = [google_compute_instance.compute-csye6225]
}
resource "google_vpc_access_connector" "connector" {
  name          = "vpc-connector"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.self_link
  machine_type = "f1-micro"
  min_instances = "2"
  max_instances = "3"
  depends_on = [ google_compute_network.vpc ]
}
  
resource "google_service_account" "cloud_function_SA" {
  account_id   = "cloud-function-service-account"
  display_name = "Cloud Function Service Account"
}
resource "google_pubsub_topic" "email_topic" {
  name = "email-pub-sub"
  message_retention_duration = "604800s"
}

resource "google_project_iam_binding" "pubsub_publisher_binding" {
  project = var.project
  role    = "roles/pubsub.publisher"
  members = [
    "serviceAccount:${google_service_account.my_service_account.email}",
  ]
}

resource "google_project_iam_binding" "pubsub_subscriber_binding" {
  project = var.project
  role    = "roles/pubsub.subscriber"
  members = [
    "serviceAccount:${google_service_account.cloud_function_SA.email}",
  ]
}

resource "google_project_iam_binding" "storage_object_viewer_binding" {
  project = var.project
  role    = "roles/storage.objectViewer"
  members = [
    "serviceAccount:${google_service_account.cloud_function_SA.email}",
  ]
}

resource "google_project_iam_binding" "logging_log_writer_binding" {
  project = var.project
  role    = "roles/logging.logWriter"
  members = [
    "serviceAccount:${google_service_account.cloud_function_SA.email}",
  ]
}

resource "google_project_iam_binding" "cloud_sql_client_binding" {
  project = var.project
  role    = "roles/cloudsql.client"
  members = [
    "serviceAccount:${google_service_account.cloud_function_SA.email}",
  ]
}

resource "google_cloudfunctions2_function" "email_function" {
  name        = "email-function"
  description = "Send emails via Pub/Sub"
  location    = "us-east1"

  build_config {
    runtime     = "python39"
    entry_point = "hello_pubsub"
    source {
      storage_source {
        bucket = "abhinavp-bucket1"
        object = "funct-test/function-final.zip"
      }
    }
  }

  service_config {
    max_instance_count = 1
    min_instance_count = 0
    available_memory   = "256M"
    timeout_seconds = 60
    max_instance_request_concurrency = 1
    available_cpu = "1"
    environment_variables = {
      DB_USER     = google_sql_user.mysql_user_1.name
      DB_PASSWORD = google_sql_user.mysql_user_1.password
      DB_NAME     = google_sql_database.mysql_db_1.name
      DB_HOST     = google_sql_database_instance.db_instance_10.private_ip_address
      INSTANCE    = google_sql_database_instance.db_instance_10.name
      API_KEY     = var.api_key_mailgun
      IP          = google_compute_instance.compute-csye6225.network_interface[0].access_config[0].nat_ip
    }
    service_account_email = google_service_account.cloud_function_SA.email
    vpc_connector         = google_vpc_access_connector.connector.self_link
    ingress_settings = "ALLOW_ALL"
  }
  

  event_trigger {
    trigger_region = "us-east1"
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic = google_pubsub_topic.email_topic.id
  }

  depends_on = [
    google_vpc_access_connector.connector
  ]
}
