resource "google_project_service" "required" {
  for_each = toset(local.required_services)

  project = var.project_id
  service = each.value

  # Teardown (LAB-19) removes what the lab created. An attendee's project may
  # have been using these before the workshop.
  disable_on_destroy = false
}
