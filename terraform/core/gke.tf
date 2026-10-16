# GKE Standard, zonal cluster inside aditest-vpc
# Requires the subnet secondary ranges "gke-pods" and "gke-services" in main.tf

# ---------- APIs ----------
resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# ---------- Node service account (least privilege, not the default compute SA) ----------
resource "google_service_account" "gke_nodes" {
  account_id   = "gke-nodes"
  display_name = "GKE node service account"
}

resource "google_project_iam_member" "gke_nodes_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ---------- Cluster (control plane) ----------
resource "google_container_cluster" "primary" {
  name     = "aditest-gke"
  location = var.zone # zonal cluster

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.mumbai.id

  # We manage nodes in a separate node pool below
  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  secret_manager_config {
    enabled = true
  }

  # Nodes get private IPs only (outbound via Cloud NAT); API endpoint stays public
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Allow `terraform destroy` while learning; set to true for real environments
  deletion_protection = false

  depends_on = [
    google_project_service.container,
    google_compute_router_nat.nat,
  ]
}

# ---------- Node pool (worker nodes) ----------
resource "google_container_node_pool" "default" {
  name     = "default-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  initial_node_count = 2

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 50
    disk_type    = "pd-balanced"
    # spot       = true   # uncomment for ~60-90% cheaper, interruptible nodes

    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      env = "dev"
    }
  }

  depends_on = [google_project_iam_member.gke_nodes_roles]
}

# ---------- Artifact Registry (where your app images go, like ECR) ----------
resource "google_artifact_registry_repository" "apps" {
  repository_id = "apps"
  location      = var.region
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry]
}

# ---------- Outputs ----------
output "gke_cluster_name" {
  value = google_container_cluster.primary.name
}

output "gke_get_credentials" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}"
}

output "docker_repo" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.apps.repository_id}"
}
