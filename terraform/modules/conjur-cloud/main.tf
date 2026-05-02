# ============================================================
# conjur-cloud module
#
# Replicates the full config.sh workflow using first-class
# Terraform resources from cyberark/conjur >= 0.8.0:
#
#   1. JWT authenticator            (conjur_authenticator)
#   2. Policy branch hierarchy      (conjur_policy_branch)
#   3. Workload group + host        (conjur_group / conjur_host)
#   4. Authenticator grant          (conjur_membership)
#   5. Host → group membership      (conjur_membership)
#   6. Secrets + access grants      (conjur_secret w/ permissions)
#
# Conjur rejects concurrent policy loads under the same branch
# with 409 Conflict.  Always run terraform with -parallelism=1.
# ============================================================

locals {
  authenticator_id = "${var.swa_resource_prefix}-jwt-authenticator"
}

# ── 1. JWT Authenticator ──────────────────────────────────────
#
# Equivalent to:
#   conjur policy load -b conjur/authn-jwt -f jwt-authenticator.yaml
#   conjur variable set -i conjur/authn-jwt/<id>/jwks-uri    -v ...
#   conjur variable set -i conjur/authn-jwt/<id>/issuer      -v ...
#   conjur variable set -i conjur/authn-jwt/<id>/audience    -v ...
#   conjur variable set -i conjur/authn-jwt/<id>/identity-path -v ...
#   conjur variable set -i conjur/authn-jwt/<id>/token-app-property -v sub
#   conjur authenticator enable --id authn-jwt/<id>
resource "conjur_authenticator" "jwt" {
  type    = "jwt"
  name    = local.authenticator_id
  enabled = true

  data = {
    audience = var.conjur_jwt_audience
    issuer   = var.swa_oidc_issuer_url
    jwks_uri = "${var.swa_oidc_issuer_url}/.well-known/jwks"
    identity = {
      identity_path      = "data/${var.swa_resource_prefix}/workloads"
      token_app_property = "sub"
    }
  }

  annotations = {
    description = "JWT authenticator for ${var.swa_resource_prefix}"
    swa_prefix  = var.swa_resource_prefix
  }
}

# ── 2a. Policy branch: data/${prefix} ────────────────────────
#
# Equivalent to the implicit parent branch created when loading
# a policy with id: ${prefix}/workloads under -b data.
resource "conjur_policy_branch" "prefix" {
  branch = "data"
  name   = var.swa_resource_prefix

  annotations = {
    description = "Root namespace for ${var.swa_resource_prefix}"
  }
}

# ── 2b. Policy branch: data/${prefix}/workloads ──────────────
#
# Equivalent to:
#   conjur policy load -b data -f policy-tree.yaml   (creates the branch)
#   conjur policy load -b data -f workload-identities.yaml (populates it)
resource "conjur_policy_branch" "workloads" {
  branch = conjur_policy_branch.prefix.full_id
  name   = "workloads"

  annotations = {
    description = "Workload identities for ${var.swa_resource_prefix}"
  }

  depends_on = [conjur_policy_branch.prefix]
}

# ── 2c. Policy branch: data/${prefix}/secrets ────────────────
resource "conjur_policy_branch" "secrets" {
  branch = conjur_policy_branch.prefix.full_id
  name   = "secrets"

  annotations = {
    description = "Secrets namespace for ${var.swa_resource_prefix}"
  }

  # Sequential with workloads — same parent, avoids 409 on parallel load
  depends_on = [conjur_policy_branch.workloads]
}

# ── 2d. Policy branch: …/secrets/saas-external-apis ──────────
resource "conjur_policy_branch" "saas_external_apis" {
  branch = conjur_policy_branch.secrets.full_id
  name   = "saas-external-apis"

  annotations = {
    description = "External SaaS API credentials"
  }

  depends_on = [conjur_policy_branch.secrets]
}

# ── 2e. Policy branch: …/saas-external-apis/openweather ──────
resource "conjur_policy_branch" "openweather" {
  branch = conjur_policy_branch.saas_external_apis.full_id
  name   = "openweather"

  depends_on = [conjur_policy_branch.saas_external_apis]
}

# ── 2f. Policy branch: …/saas-external-apis/timezone ─────────
resource "conjur_policy_branch" "timezone" {
  branch = conjur_policy_branch.saas_external_apis.full_id
  name   = "timezone"

  # Sequential with openweather — same parent, avoids 409
  depends_on = [conjur_policy_branch.openweather]
}

# ── 3a. Workload group: …/workloads/apps ─────────────────────
#
# Equivalent to:  !group id: apps  inside workload-identities.yaml
resource "conjur_group" "workload_apps" {
  name   = "apps"
  branch = conjur_policy_branch.workloads.full_id

  annotations = {
    description = "Application workloads for ${var.swa_resource_prefix}"
  }

  depends_on = [conjur_policy_branch.workloads]
}

# ── 3b. Workload host: …/workloads/${nodegroup} ───────────────
#
# Equivalent to:
#   !host
#     id: ${SPIFFE_SUBJECT}
#     annotations:
#       authn-jwt/<id>/sub: ${SPIFFE_SUBJECT}
resource "conjur_host" "workload" {
  name   = var.swa_nodegroup_name
  branch = conjur_policy_branch.workloads.full_id

  annotations = {
    description                                    = "Workload identity for ${var.swa_resource_prefix}"
    "authn-jwt/${local.authenticator_id}/sub"      = var.spiffe_subject
  }

  authn_descriptors = [
    { type = "api_key" }
  ]

  depends_on = [
    conjur_authenticator.jwt,
    conjur_group.workload_apps,
  ]
}

# ── 4. Host → workloads/apps group ───────────────────────────
#
# Equivalent to:
#   !grant
#     role: !group apps
#     members:
#       - !host ${SPIFFE_SUBJECT}
resource "conjur_membership" "host_to_apps" {
  group_id    = "${conjur_policy_branch.workloads.full_id}/apps"
  member_kind = "host"
  member_id   = "${conjur_policy_branch.workloads.full_id}/${var.swa_nodegroup_name}"

  depends_on = [conjur_host.workload, conjur_group.workload_apps]
}

# ── 5. workloads/apps → JWT authenticator apps group ─────────
#
# Equivalent to authn-jwt-grant.yaml:
#   !grant
#     role: !group apps          (authenticator's apps group)
#     members:
#       - !group /data/${prefix}/workloads/apps
resource "conjur_membership" "apps_to_authn" {
  group_id    = "conjur/authn-jwt/${local.authenticator_id}/apps"
  member_kind = "group"
  member_id   = "${conjur_policy_branch.workloads.full_id}/apps"

  depends_on = [conjur_membership.host_to_apps]
}

# ── 6a. Secret: openweather/api-key ──────────────────────────
#
# Equivalent to:
#   !variable id: openweather/api-key  (in secrets.yaml)
#   !permit role: !host ... privilege: [read, execute]
#   conjur variable set -i …/openweather/api-key -v "..."
#
# value_wo is write-only: the value is pushed to Conjur but never
# stored in Terraform state.  Increment value_wo_version to rotate.
resource "conjur_secret" "openweather_api_key" {
  name   = "api-key"
  branch = conjur_policy_branch.openweather.full_id

  value_wo         = var.openweather_api_key
  value_wo_version = 1

  annotations = {
    description = "OpenWeather external API key"
  }

  permissions = [
    {
      subject = {
        kind = "host"
        id   = "${conjur_policy_branch.workloads.full_id}/${var.swa_nodegroup_name}"
      }
      privileges = ["read", "execute"]
    }
  ]

  depends_on = [conjur_policy_branch.openweather, conjur_membership.apps_to_authn]
}

# ── 6b. Secret: timezone/token ────────────────────────────────
resource "conjur_secret" "timezone_token" {
  name   = "token"
  branch = conjur_policy_branch.timezone.full_id

  value_wo         = var.timezone_token
  value_wo_version = 1

  annotations = {
    description = "Timezone external API token"
  }

  permissions = [
    {
      subject = {
        kind = "host"
        id   = "${conjur_policy_branch.workloads.full_id}/${var.swa_nodegroup_name}"
      }
      privileges = ["read", "execute"]
    }
  ]

  depends_on = [conjur_policy_branch.timezone, conjur_membership.apps_to_authn]
}
