resource "google_service_account" "agent" {
  project      = var.project_id
  account_id   = local.agent_service_account_id
  display_name = "Agentic SDLC workshop — deployed coder agent"
  description  = "Runtime identity of the Agent Runtime engine deployed in lab step 3."

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "agent" {
  for_each = toset(local.agent_project_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.agent.email}"
}

# Agent Runtime mints tokens for the engine's service account through this
# principal, so a deploy naming the service account is refused without it. The
# principal exists only once the project has deployed an engine, which is why
# the caller states whether it is there rather than Terraform assuming.
resource "google_service_account_iam_member" "runtime_agent_impersonation" {
  count = var.runtime_service_agent_exists ? 1 : 0

  service_account_id = google_service_account.agent.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${local.runtime_service_agent}"
}
