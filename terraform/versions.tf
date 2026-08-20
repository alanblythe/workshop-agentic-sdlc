terraform {
  # 1.9 for cross-variable validation: model_location is checked against
  # agent_engine_location on the variable itself.
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.28.0, < 8.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.agent_engine_location
}
