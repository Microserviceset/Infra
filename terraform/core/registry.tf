import {
  to = google_artifact_registry_repository.microservices
  id = "projects/aditest-511508/locations/asia-south1/repositories/microservices"
}

resource "google_artifact_registry_repository" "microservices" {
  project                = "aditest-511508"
  location               = "asia-south1"
  repository_id          = "microservices"
  format                 = "DOCKER"
  cleanup_policy_dry_run = true

  docker_config {
    immutable_tags = false
  }
}
