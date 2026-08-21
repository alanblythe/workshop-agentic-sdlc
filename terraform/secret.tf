# Terraform owns the container. The value, a deploy key generated against the
# attendee's fork, is added as a version on the day, and nothing here diffs it.
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

# The deployed engine runs under Agent Identity, so there is no service account
# to grant. Its principal is federated, and this member covers every Agent
# Runtime agent in the project rather than one engine by id.
resource "google_secret_manager_secret_iam_member" "agent_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.deploy_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.agent_principal_set

  lifecycle {
    precondition {
      condition     = local.agent_trust_domain != ""
      error_message = "Cannot derive the agent trust domain: this project reports a folder parent and no org_id, so whether its pool is named after the organization or the project is unknown. Pass -var=\"agent_trust_domain=agents.global.org-<ORG_ID>.system.id.goog\" with the organization the folder belongs to. Guessing produces a binding that is accepted and grants nothing."
    }
  }
}
