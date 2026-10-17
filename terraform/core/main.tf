terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.36, < 4.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# ---------- Variables ----------
variable "project_id" {
  default = "aditest-511508"
}

variable "region" {
  default = "asia-south1"
}

variable "zone" {
  default = "asia-south1-a"
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ---------- APIs ----------
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iap" {
  service            = "iap.googleapis.com"
  disable_on_destroy = false
}

# ---------- VPC (global) ----------
resource "google_compute_network" "vpc" {
  name                    = "aditest-vpc"
  auto_create_subnetworks = false # custom mode
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.compute]
}

# ---------- Subnet (regional) ----------
resource "google_compute_subnetwork" "mumbai" {
  name                     = "aditest-subnet-mum"
  network                  = google_compute_network.vpc.id
  region                   = var.region
  ip_cidr_range            = "10.10.0.0/20" # nodes and VMs
  private_ip_google_access = true

  # Secondary ranges used by GKE (VPC-native cluster)
  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.30.0.0/20"
  }
}

# ---------- Firewall (security-group equivalent) ----------
resource "google_compute_firewall" "allow_internal" {
  name          = "aditest-allow-internal"
  network       = google_compute_network.vpc.name
  source_ranges = ["10.10.0.0/16"]

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
}

resource "google_compute_firewall" "allow_ssh_iap" {
  name          = "aditest-allow-ssh-iap"
  network       = google_compute_network.vpc.name
  source_ranges = ["35.235.240.0/20"] # Google IAP range
  target_tags   = ["ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ---------- Cloud Router + Cloud NAT (NAT Gateway equivalent) ----------
resource "google_compute_router" "router" {
  name    = "aditest-router"
  network = google_compute_network.vpc.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "aditest-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ---------- Test VM (private, no public IP) ----------
resource "google_compute_instance" "test_vm" {
  name         = "test-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.mumbai.id
    # no access_config block = no external IP
  }

  depends_on = [google_compute_router_nat.nat]
}

# ---------- Outputs ----------
output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "subnet_cidr" {
  value = google_compute_subnetwork.mumbai.ip_cidr_range
}

output "vm_private_ip" {
  value = google_compute_instance.test_vm.network_interface[0].network_ip
}