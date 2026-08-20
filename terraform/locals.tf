data "google_project" "this" {
  project_id = var.project_id
}

locals {
  # A fixed string, not a variable. Day-of lab steps address this secret by name
  # in a different clone of a different repo, possibly a week later.
  deploy_key_secret_id = "agentic-sdlc-deploy-key"

  required_services = [
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudtrace.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ]

  # The trust domain is the workload identity pool the agent's principal lives
  # in, and it is named after the project's parent. A project directly under an
  # organization and one with no organization at all get different pools, and a
  # project under a folder does not report an org_id here at all — hence the
  # override, and the precondition in secret.tf that refuses to guess.
  derived_trust_domain = (
    data.google_project.this.org_id != "" ?
    "agents.global.org-${data.google_project.this.org_id}.system.id.goog" :
    data.google_project.this.folder_id == "" ?
    "agents.global.project-${data.google_project.this.number}.system.id.goog" :
    ""
  )

  agent_trust_domain = var.agent_trust_domain != "" ? var.agent_trust_domain : local.derived_trust_domain

  # Every Agent Runtime agent in this project, rather than one engine by id.
  # No engine id appears in it, so the grant can be made before the engine
  # exists — which is what lets preflight run a week before the session.
  agent_principal_set = "principalSet://${local.agent_trust_domain}/attribute.platformContainer/aiplatform/projects/${data.google_project.this.number}"
}
