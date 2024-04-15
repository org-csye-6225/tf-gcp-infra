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

resource "google_project_iam_member" "grant-google-cloud-sql-encrypt-decrypt" {
  project    = var.project
  role       = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member     = "serviceAccount:service-938986387663@gcp-sa-cloud-sql.iam.gserviceaccount.com"
  depends_on = [ google_kms_crypto_key.cloudsql_encryption_key]
}

 resource "google_sql_database_instance" "db_instance_10" {
  name             = "db-instance-10"
  database_version = "MYSQL_8_0"
  region           = var.region

  encryption_key_name = google_kms_crypto_key.cloudsql_encryption_key.id
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
  depends_on = [google_service_networking_connection.default, google_project_iam_member.grant-google-cloud-sql-encrypt-decrypt]
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
resource "google_dns_record_set" "mx_record" {
  name         = "abhinavpandey.tech."
  type         = "MX"
  ttl          = 360
  managed_zone = "abhinav-csye6225"

  rrdatas = [
    "10 mxa.mailgun.org.",
    "10 mxb.mailgun.org."
  ]
  depends_on = [google_compute_region_instance_template.compute-csye6225]
}

resource "google_dns_record_set" "txt_record" {
  name         = "abhinavpandey.tech."
  type         = "TXT"
  ttl          = 360
  managed_zone = "abhinav-csye6225"

  rrdatas = [
    "\"v=spf1 include:mailgun.org ~all\""
  ]
  depends_on = [google_compute_region_instance_template.compute-csye6225]
}

resource "google_dns_record_set" "cname_record" {
  name         = "email.abhinavpandey.tech."
  type         = "CNAME"
  ttl          = 360
  managed_zone = "abhinav-csye6225"

  rrdatas = [
    "mailgun.org."
  ]
  depends_on = [google_compute_region_instance_template.compute-csye6225]
}
resource "google_dns_record_set" "txt_domainkey_record" {
  name         = "pic._domainkey.abhinavpandey.tech."
  type         = "TXT"
  ttl          = 360
  managed_zone = "abhinav-csye6225"

  rrdatas = [
    var.domain_key_record
  ]
  depends_on = [google_compute_region_instance_template.compute-csye6225]
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
        bucket = "encrypted_abhinav_bucket"
        object = "function-final.zip"
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
    google_vpc_access_connector.connector, google_storage_bucket_object.my_zip_file
  ]
}
## Google Secret manager
resource "google_secret_manager_secret" "mysql_pswd" {
  secret_id = "mysql_pswd"
 
  replication {
    auto {}
  }
}
 
resource "google_secret_manager_secret_version" "secret-version-pass" {
  secret = google_secret_manager_secret.mysql_pswd.id
  secret_data = random_string.database_pswd.result 
}
resource "google_secret_manager_secret" "mysql_host_ip" {
  secret_id = "mysql_host_ip"
 
  replication {
    auto {}
  }
}
 
resource "google_secret_manager_secret_version" "secret-version-host" {
  secret = google_secret_manager_secret.mysql_host_ip.id
  secret_data = google_sql_database_instance.db_instance_10.private_ip_address
}


## CMEK 
resource "google_kms_key_ring" "my_key_ring" {
  name     = "my-key-ring-${formatdate("YYYY-MM-DD_hh-mm-ss", timestamp())}"
  location = var.region
}

resource "google_kms_crypto_key" "vm_disk_encryption_key" {
  name     = "vm-disk-encryption-key"
  key_ring = google_kms_key_ring.my_key_ring.id
  rotation_period = "2592000s"

  lifecycle {
  prevent_destroy = false
  }
  depends_on = [google_kms_key_ring.my_key_ring]
}


resource "google_kms_crypto_key" "cloudsql_encryption_key" {
  name     = "cloudsql-encryption-key"
  key_ring = google_kms_key_ring.my_key_ring.id
  rotation_period = "2592000s"
  lifecycle {
    prevent_destroy = false
  }
  depends_on = [google_kms_key_ring.my_key_ring]
}

resource "google_storage_bucket_object" "my_zip_file" {
  name   = "function-final.zip"
  bucket = google_storage_bucket.encrypted_abhinav_bucket.name
  source = var.pathtozip
  depends_on = [google_storage_bucket.encrypted_abhinav_bucket]
}

resource "google_kms_crypto_key" "bucket_encryption_key" {
  name     = "bucket_encryption_key"
  key_ring = google_kms_key_ring.my_key_ring.id
  rotation_period = "2592000s"
  lifecycle {
    prevent_destroy = false
  }
  depends_on = [google_kms_key_ring.my_key_ring]
}

resource "google_project_iam_member" "grant-google-storage-service-encrypt-decrypt" {
  project    = var.project
  role       = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member     = "serviceAccount:service-938986387663@gs-project-accounts.iam.gserviceaccount.com"
  depends_on = [ google_kms_crypto_key.bucket_encryption_key]
}
 
 
resource "google_storage_bucket" "encrypted_abhinav_bucket" {
  name     = "encrypted_abhinav_bucket"
  project  = var.project
  location = var.region
 
  encryption {
    default_kms_key_name = google_kms_crypto_key.bucket_encryption_key.id
  }
 
  depends_on = [google_kms_crypto_key.bucket_encryption_key, google_kms_key_ring.my_key_ring, google_project_iam_member.grant-google-storage-service-encrypt-decrypt]
}


resource "google_project_iam_member" "vm_instance_binding" {
  project    = var.project
  role       = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member     = "serviceAccount:service-938986387663@compute-system.iam.gserviceaccount.com"
  depends_on = [ google_kms_crypto_key.vm_disk_encryption_key]
}

## load balancer related code here: 
resource "google_compute_firewall" "allow_lb" {
  name    = "allow-lb"
  network = google_compute_network.vpc.self_link
  project = var.project

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = [google_compute_global_address.lb_ipv4_addr.address, "130.211.0.0/22", "35.191.0.0/16"]
  depends_on = [google_compute_network.vpc, google_compute_global_address.lb_ipv4_addr]
}
resource "google_compute_region_instance_template" "compute-csye6225" {
  name        = "my-instance-template"
  machine_type = "e2-standard-2"
  project     = var.project

  disk {
    source_image = "projects/tf-csye-6225-project/global/images/custom-image-with-pubsub-1712120987"
    disk_size_gb  = 100
    type  = "pd-balanced"
    auto_delete = true
    boot        = true
    disk_encryption_key {
      kms_key_self_link = google_kms_crypto_key.vm_disk_encryption_key.id
    }
  }

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

depends_on = [
  google_sql_database_instance.db_instance_10,
  google_service_account.my_service_account,
  google_project_iam_binding.logging_admin_binding,
  google_project_iam_binding.monitoring_metric_writer_binding
  ]
}
resource "google_compute_http_health_check" "health_check" {
  name               = "health-check"
  request_path       = "/healthz"
  port               = 3000
  check_interval_sec = 60
  timeout_sec        = 60
  healthy_threshold  = 8
  unhealthy_threshold = 10
  depends_on = [ google_compute_region_instance_template.compute-csye6225]
}

resource "google_compute_region_autoscaler" "my_autoscaler" {
  name               = "my-autoscaler"
  region             = var.region
  target             = google_compute_region_instance_group_manager.instance_group.id
  autoscaling_policy {
    min_replicas      = var.min_replicas
    max_replicas      = var.max_replicas
    cooldown_period   = 150
    cpu_utilization {
      target = var.cpu_util
    }
  }
  depends_on = [ google_compute_region_instance_template.compute-csye6225]
}

resource "google_compute_region_instance_group_manager" "instance_group" {
  name               = "my-instance-group"
  base_instance_name = "my-instance"
  project            = var.project
  region             = var.region
  distribution_policy_zones = [ "us-east1-b","us-east1-c","us-east1-d"]

  target_size        = 1

auto_healing_policies { 
    health_check = google_compute_http_health_check.health_check.id
    initial_delay_sec = 150
  }
   version {
    name = "instance-template-version"
    instance_template = google_compute_region_instance_template.compute-csye6225.self_link
  }

  named_port {
    name = "http"
    port = 3000
  }
  depends_on  = [google_compute_region_instance_template.compute-csye6225]
}

resource "google_compute_global_address" "lb_ipv4_addr" {
  name = "lb-ipv4-addr"
  ip_version = "IPV4"
  address_type = "EXTERNAL"
}

resource "google_compute_managed_ssl_certificate" "managed_cert" {
  name = "managed-cert"

  managed {
    domains = ["abhinavpandey.tech"]
  }
}

resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "https-proxy"
  ssl_certificates = [google_compute_managed_ssl_certificate.managed_cert.self_link]
  url_map          = google_compute_url_map.url_map.self_link
}

resource "google_compute_url_map" "url_map" {
  name            = "url-map"
  default_service = google_compute_backend_service.backend_service.self_link
}

resource "google_compute_backend_service" "backend_service" {
  name                  = "backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_http_health_check.health_check.self_link]
  locality_lb_policy    = "ROUND_ROBIN"
  timeout_sec           = 150
  backend {
    group = google_compute_region_instance_group_manager.instance_group.instance_group
  }
  depends_on = [ google_compute_region_instance_group_manager.instance_group ]
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name                  = "forwarding-rule"
  target                = google_compute_target_https_proxy.https_proxy.self_link
  ip_address            = google_compute_global_address.lb_ipv4_addr.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"  
}

resource "google_dns_record_set" "dns_record" {
  name         = "abhinavpandey.tech."
  type         = "A"
  ttl          = 360
  managed_zone = "abhinav-csye6225"

  rrdatas = [
    google_compute_global_address.lb_ipv4_addr.address
  ]
}
