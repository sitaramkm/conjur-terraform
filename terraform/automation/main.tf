# Automation workspace — manages secret values under the policy branch
# created by the admin workspace.
#
# Prerequisites: run `./scripts/conjur-tf.sh admin-setup` first to create the
# policy branch and grant the workload host access to secrets within it.
#
# Secrets have prevent_destroy = true: to remove them, run `admin-teardown`
# which deletes the entire policy branch (and all resources under it) via the
# admin CLI session.

resource "conjur_secret" "openweather_api_key" {
  branch   = "data/${var.conjur_resource_prefix}"
  name     = "openweather-api-key"
  value_wo = var.openweather_api_key

  lifecycle {
    prevent_destroy = true
  }
}

resource "conjur_secret" "timezone_token" {
  branch   = "data/${var.conjur_resource_prefix}"
  name     = "timezone-token"
  value_wo = var.timezone_token

  lifecycle {
    prevent_destroy = true
  }
}
