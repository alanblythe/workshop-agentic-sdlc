locals {
  # Fixed strings, not variables. Day-of lab steps address these resources by
  # name in a different clone of a different repo, possibly a week later.
  agent_service_account_id = "agentic-sdlc-coder"
  deploy_key_secret_id     = "agentic-sdlc-deploy-key"

  required_services = [
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudtrace.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ]

  agent_project_roles = [
    "roles/aiplatform.user",
    "roles/serviceusage.serviceUsageConsumer", # its absence breaks every Google API call, not just the one under test
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent",
  ]

  runtime_service_agent = "service-${data.google_project.this.number}@gcp-sa-aiplatform-re.iam.gserviceaccount.com"
}
