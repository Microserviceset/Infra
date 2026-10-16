terraform {
  backend "gcs" {
    bucket = "aditest-511508-tfstate"
    prefix = "core"
  }
}
