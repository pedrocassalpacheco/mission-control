terraform {
  required_providers {
    tls = {
      source = "hashicorp/tls"
      version = "4.0.5"
    }
    google = {
      source = "hashicorp/google"
      version = "5.28.0"
    }
    local = {
      source = "hashicorp/local"
      version = "2.5.1"
    }
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# Service Account
resource "google_service_account" "service_account" {
  account_id   = "${var.prefix}-mc-sa"
  display_name = "${var.prefix} Mission Control Service Account"
}

# GCE Instance IAM Role
resource "google_project_iam_custom_role" "gce_sa_role" {
  role_id = format("%s%s", replace(var.prefix, "-", ""), "MCSA")
  title = "GCE Service Account Role"
  permissions = [
    "artifactregistry.repositories.downloadArtifacts",
    "autoscaling.sites.writeMetrics",
    "logging.logEntries.create",
    "monitoring.dashboards.get",
    "monitoring.metricDescriptors.list",
    "monitoring.timeSeries.create",
    "monitoring.timeSeries.list",
    "serviceusage.services.use"
  ]
}

resource "google_project_iam_member" "gce_sa_role_member" {
  project = var.gcp_project
  role    = google_project_iam_custom_role.gce_sa_role.name
  member  = google_service_account.service_account.member
}

# Metrics
resource "google_storage_bucket" "metrics_bucket" {
  name          = "${var.prefix}-mc-metrics"
  storage_class = "REGIONAL"
  location      = var.gcp_region
  force_destroy = true
  uniform_bucket_level_access = true
  public_access_prevention = "enforced"
  soft_delete_policy {
    retention_duration_seconds = 0
  }
}

resource "google_storage_bucket_iam_binding" "metrics_bucket_object_admin_binding" {
  bucket = google_storage_bucket.metrics_bucket.name
  role = "roles/storage.objectAdmin"
  members = [
    google_service_account.service_account.member,
  ]
}

# Logs
resource "google_storage_bucket" "logs_bucket" {
  name          = "${var.prefix}-mc-logs"
  storage_class = "REGIONAL"
  location      = var.gcp_region
  force_destroy = true
  uniform_bucket_level_access = true
  public_access_prevention = "enforced"
  soft_delete_policy {
    retention_duration_seconds = 0
  }
}

resource "google_storage_bucket_iam_binding" "logs_bucket_object_admin_binding" {
  bucket = google_storage_bucket.logs_bucket.name
  role = "roles/storage.objectAdmin"
  members = [
    google_service_account.service_account.member,
  ]
}

# Backups
resource "google_storage_bucket" "backups_bucket" {
  name          = "${var.prefix}-mc-backups"
  storage_class = "REGIONAL"
  location      = var.gcp_region
  force_destroy = true
  uniform_bucket_level_access = true
  public_access_prevention = "enforced"
  soft_delete_policy {
    retention_duration_seconds = 0
  }
}

resource "google_storage_bucket_iam_binding" "backups_bucket_object_admin_binding" {
  bucket = google_storage_bucket.backups_bucket.name
  role = "roles/storage.objectAdmin"
  members = [
    google_service_account.service_account.member,
  ]
}

# GKE Cluster
resource "google_container_cluster" "control_plane" {
  name     = "${var.prefix}-mc-control-plane"
  location = var.gcp_zone
  network = var.gcp_network

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  enable_l4_ilb_subsetting = true
  deletion_protection = false
}

resource "google_container_node_pool" "control_plane_platform_node_pool" {
  name       = "${var.prefix}-mc-cp-pl-np"
  location   = var.gcp_zone
  cluster    = google_container_cluster.control_plane.name

  autoscaling {
    min_node_count = 0
    max_node_count = 3
    location_policy = "BALANCED"
  }

  node_config {
    preemptible  = true
    machine_type = var.platform_instance_type
    disk_type = "pd-ssd"
    disk_size_gb = 100
    labels = {
      "mission-control.datastax.com/role" = "platform"
    }

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.service_account.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_container_node_pool" "control_plane_database_node_pool" {
  name       = "${var.prefix}-mc-cp-db-np"
  location   = var.gcp_zone
  cluster    = google_container_cluster.control_plane.name

  autoscaling {
    min_node_count = 0
    max_node_count = 3
    location_policy = "BALANCED"
  }

  node_config {
    machine_type = var.database_instance_type
    disk_type = "pd-ssd"
    disk_size_gb = 100
    labels = {
      "mission-control.datastax.com/role" = "database"
    }

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.service_account.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}