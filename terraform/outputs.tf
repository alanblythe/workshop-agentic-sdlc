# Informational, for preflight to echo back. The two names are also derivable
# from the naming convention, because day-of steps run in a different clone and
# cannot read this state. Nothing on the day may consume these.

output "agent_service_account_email" {
  description = "Pass this to `agents-cli deploy --service-account`."
  value       = google_service_account.agent.email
}

output "deploy_key_secret_id" {
  description = "The empty secret the deploy key is written into on the day."
  value       = google_secret_manager_secret.deploy_key.secret_id
}

output "runtime_service_agent_email" {
  description = "The Agent Runtime service agent. Created by the project's first engine deploy."
  value       = local.runtime_service_agent
}

output "runtime_service_agent_impersonation_granted" {
  description = "False means the deploy cannot yet run as the agent service account; re-apply once an engine has deployed."
  value       = var.runtime_service_agent_exists
}
