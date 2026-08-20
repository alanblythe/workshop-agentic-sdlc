# Terraform owns the container. The value — a deploy key generated against the
# attendee's fork — is added as a version on the day, and nothing here diffs it.
resource "google_secret_manager_secret" "deploy_key" {
  project   = var.project_id
  secret_id = local.deploy_key_secret_id

  labels = {
    workshop = "agentic-sdlc"
  }

  # User-managed replication keeps the secret inside one named region, which an
  # org policy on resource locations will otherwise refuse.
  replication {
    user_managed {
      replicas {
        location = var.agent_engine_location
      }
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_iam_member" "agent_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.deploy_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.agent.email}"
}
