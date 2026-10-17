# Short-lived token of whoever runs Terraform (you locally, or the CI service account)
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

resource "kubernetes_namespace_v1" "env" {
  for_each = toset(["staging", "production"])

  metadata {
    name = each.key
    labels = {
      environment  = each.key
      "managed-by" = "terraform"
    }
  }
}
