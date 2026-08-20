# Informational, for preflight to echo back. The secret name is also derivable
# from the naming convention, because day-of steps run in a different clone and
# cannot read this state. Nothing on the day may consume these.

output "deploy_key_secret_id" {
  description = "The empty secret the deploy key is written into on the day."
  value       = google_secret_manager_secret.deploy_key.secret_id
}

output "agent_principal_set" {
  description = "The federated principal granted read access to the deploy key. Every Agent Runtime agent in this project matches it."
  value       = local.agent_principal_set
}

output "agent_trust_domain" {
  description = "The workload identity pool the agent's principal lives in, derived from the project's parent unless overridden."
  value       = local.agent_trust_domain
}
