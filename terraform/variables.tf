variable "project_id" {
  type        = string
  description = "The attendee's own Google Cloud project."

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id is required. Pass -var=\"project_id=$(gcloud config get-value project)\"."
  }
}

variable "agent_engine_location" {
  type        = string
  description = <<-EOT
    Where the engine runs and where its Sessions live. The workshop pins
    us-central1. Sourced from $AGENT_ENGINE_LOCATION.
  EOT

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.agent_engine_location))
    error_message = "agent_engine_location must be a region such as us-central1. 'global' is a model endpoint, not a region: interpolated into a host it yields global-aiplatform.googleapis.com, which does not resolve."
  }
}

variable "model_location" {
  type        = string
  description = <<-EOT
    Which endpoint serves the model. gemini-3.6-flash is served only from
    global. Sourced from $MODEL_LOCATION.

    Nothing here is provisioned from this value. It is taken so that the two
    locations are checked against each other in one place, before an attendee
    spends a deploy discovering they disagree.
  EOT

  validation {
    condition     = var.model_location == "global" || can(regex("^[a-z]+-[a-z]+[0-9]$", var.model_location))
    error_message = "model_location must be 'global' or a region. The whole Gemini 3 family answers only from 'global'; a regional endpoint returns a 404 that names the model and reads as a typo."
  }

  validation {
    condition     = var.model_location != var.agent_engine_location
    error_message = "model_location and agent_engine_location are both '${var.model_location}'. They are independent: the model answers from an endpoint and the engine runs in a region. The workshop pins a Gemini 3 model, served only from 'global', so matching them to look tidy returns a 404 that names the model."
  }
}

variable "agent_trust_domain" {
  type        = string
  default     = ""
  description = <<-EOT
    Override for the workload identity pool the agent's principal lives in,
    such as agents.global.org-1085975473437.system.id.goog.

    Leave empty and it is derived from the project's parent: the org- form for
    a project directly under an organization, the project- form for one with no
    organization. A project under a folder reports neither here, and the apply
    refuses rather than guessing, a binding to the wrong trust domain is
    accepted and grants nothing, which is worse than a failure.
  EOT
}
