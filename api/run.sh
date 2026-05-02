#!/usr/bin/env bash
set -euo pipefail

# conjur/config.sh — JWT Authenticator + role setup for Conjur demo
#
# Usage:
#   CONJUR_TENANT=<tenant-name> ./api/run.sh create
#   CONJUR_TENANT=<tenant-name> ./api/run.sh destroy
#
# Reads:
#   ./common.env    -> (for resource prefix, trust domain, node group name, OIDC info)
#
# Writes:
#   ./conjur-output.env ->
#       CONJUR_AUTHN_JWT_AUTHENTICATOR_ID
#       CONJUR_JWT_IDENTITY_PATH
#       CONJUR_JWT_AUDIENCE
#       CONJUR_RESOURCE_PREFIX
#       CONJUR_OIDC_ISSUER_URL
#       CONJUR_TENANT
#       CONJUR_SECRET_URL
#       CONJUR_SAMPLE_DB_PASSWORD_ID
#       CONJUR_SAMPLE_API_KEY_ID

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONJUR_TEMPLATE_DIR="${SCRIPT_DIR}/templates"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../" && pwd)"

COMMON_ENV="${ROOT_DIR}/common.env"

OUT_ENV="${ROOT_DIR}/conjur-output.env"

[[ -f "${COMMON_ENV}"    ]] || { echo "ERROR: ${COMMON_ENV} not found"; exit 1; }

# shellcheck disable=SC1090
source "${COMMON_ENV}"

: "${CONJUR_TENANT:?Set CONJUR_TENANT before running this script}"
: "${TF_VAR_spiffe_subject:?TF_VAR_spiffe_subject must be set in ${COMMON_ENV}}"
: "${TF_VAR_conjur_oidc_issuer_url:?TF_VAR_conjur_oidc_issuer_url must be set in ${COMMON_ENV}}"

# Derive naming from the prefix unless. Override with env vars if you need to change
export CONJUR_RESOURCE_PREFIX="${TF_VAR_conjur_resource_prefix:-conjur-demo}"
export CONJUR_JWT_AUDIENCE="${TF_VAR_conjur_jwt_audience:-conjur}"
export CONJUR_AUTHN_JWT_AUTHENTICATOR_ID="${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID:-${CONJUR_RESOURCE_PREFIX}-jwt-authenticator}"
export SPIFFE_SUBJECT="${TF_VAR_spiffe_subject}"
export CONJUR_OIDC_ISSUER_URL="${TF_VAR_conjur_oidc_issuer_url}"
CONJUR_JWT_IDENTITY_PATH="${CONJUR_JWT_IDENTITY_PATH:-data/${CONJUR_RESOURCE_PREFIX}/workloads}"

# envsubst is required for the templated YAMLs
if ! command -v envsubst >/dev/null 2>&1; then
  echo "ERROR: envsubst not found. Install gettext (e.g. 'apt-get install gettext-base') and retry."
  exit 1
fi

require_conjur_login() {
  echo "==> Checking Conjur CLI session..."
  set +e
  WHOAMI_OUTPUT="$(conjur whoami 2>&1)"
  WHOAMI_RC=$?
  set -e

  if [[ ${WHOAMI_RC} -ne 0 ]]; then
    echo "ERROR: Conjur CLI is not authenticated or session has expired."
    echo
    echo "conjur whoami output:"
    echo "---------------------"
    echo "${WHOAMI_OUTPUT}"
    echo "---------------------"
    echo
    echo "Please login to Conjur tenant '${CONJUR_TENANT}' and retry."
    echo "For example (Conjur Cloud):"
    echo "  conjur login -u <username> -p <password>"
    exit 1
  fi

  echo "    $(echo "${WHOAMI_OUTPUT}" | head -n1)"
}

create() {
  require_conjur_login

  echo "==> Configuring Conjur AuthN-JWT authenticator and policies"
  echo "    Tenant:          ${CONJUR_TENANT}"
  echo "    Resource prefix: ${CONJUR_RESOURCE_PREFIX}"
  echo "    Authenticator:   ${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID}"
  echo "    Identity path:   ${CONJUR_JWT_IDENTITY_PATH}"
  echo "    JWT audience:    ${CONJUR_JWT_AUDIENCE}"
  echo "    OIDC issuer:     ${CONJUR_OIDC_ISSUER_URL}"
  echo "    Host:            ${SPIFFE_SUBJECT}"

  GEN_DIR="${SCRIPT_DIR}/.generated"
  mkdir -p "${GEN_DIR}"

  echo "==> Rendering templated policies (envsubst)..."
  envsubst < "${CONJUR_TEMPLATE_DIR}/workload-identities.yaml.tmpl"   > "${GEN_DIR}/workload-identities.yaml"
  envsubst < "${CONJUR_TEMPLATE_DIR}/secrets.yaml.tmpl"               > "${GEN_DIR}/secrets.yaml"
  envsubst < "${CONJUR_TEMPLATE_DIR}/authn-jwt-grant.yaml.tmpl"       > "${GEN_DIR}/authn-jwt-grant.yaml"
  envsubst < "${CONJUR_TEMPLATE_DIR}/jwt-authenticator.yaml.tmpl"     > "${GEN_DIR}/jwt-authenticator.yaml"
  envsubst < "${CONJUR_TEMPLATE_DIR}/policy-tree.yaml.tmpl"           > "${GEN_DIR}/policy-tree.yaml"
  #
  # 1. JWT authenticator policy
  #
  echo "==> Loading JWT authenticator policy..."
  conjur policy load \
    -b conjur/authn-jwt \
    -f "${GEN_DIR}/jwt-authenticator.yaml"

  echo "==> Setting authenticator configuration variables..."
  conjur variable set -i "conjur/authn-jwt/${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID}/jwks-uri"           -v "${CONJUR_OIDC_ISSUER_URL}/.well-known/jwks"
  conjur variable set -i "conjur/authn-jwt/${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID}/token-app-property" -v "sub"
  conjur variable set -i "conjur/authn-jwt/${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID}/identity-path"      -v "${CONJUR_JWT_IDENTITY_PATH}"
  conjur variable set -i "conjur/authn-jwt/${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID}/issuer"             -v "${CONJUR_OIDC_ISSUER_URL}"
  conjur variable set -i "conjur/authn-jwt/${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID}/audience"           -v "${CONJUR_JWT_AUDIENCE}"

  echo "==> Enabling authenticator authn-jwt/${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID}..."
  conjur authenticator enable --id "authn-jwt/${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID}"

  #
  # 2. Policy tree for data/${CONJUR_RESOURCE_PREFIX}
  #
  echo "==> Loading policy tree (data/${CONJUR_RESOURCE_PREFIX})..."
  conjur policy load \
    -b data \
    -f "${GEN_DIR}/policy-tree.yaml"

  #
  # 3. Workload identities
  #
  echo "==> Loading workload identities..."
  conjur policy load \
    -b data \
    -f "${GEN_DIR}/workload-identities.yaml"

  #
  # 4. Grant authenticator → workloads group
  #
  echo "==> Loading authn-jwt grant policy..."
  conjur policy load \
    -b "conjur/authn-jwt/${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID}" \
    -f "${GEN_DIR}/authn-jwt-grant.yaml"

  #
  # 5. Secrets and permissions
  #
  echo "==> Loading secrets and permissions policy..."
  conjur policy load \
    -b data \
    -f "${GEN_DIR}/secrets.yaml"
  echo "    Secrets and permissions configured."

  #
  # 6. Set sample secret values
  #
  echo "==> Setting sample secret values..."

  
  CONJUR_OPENWEATHER_API_KEY_ID="data/${CONJUR_RESOURCE_PREFIX}/secrets/saas-external-apis/openweather/api-key"
  CONJUR_TIMEZONE_TOKEN_ID="data/${CONJUR_RESOURCE_PREFIX}/secrets/saas-external-apis/timezone/token"
  
  CONJUR_OPENWEATHER_API_KEY_ID_ENCODED="${CONJUR_OPENWEATHER_API_KEY_ID//\//%2F}"
  CONJUR_TIMEZONE_TOKEN_ID_ENCODED="${CONJUR_TIMEZONE_TOKEN_ID//\//%2F}"

  conjur variable set \
    -i "${CONJUR_OPENWEATHER_API_KEY_ID}" \
    -v "FAKE-OPENWEATHER-API-KEY"

  conjur variable set \
    -i "${CONJUR_TIMEZONE_TOKEN_ID}" \
    -v "FAKE-TIMEZONE-TOKEN"

  #
  # 7. Write conjur.env for downstream scripts
  #
  echo "==> Writing ${OUT_ENV}..."
  cat > "${OUT_ENV}" <<EOF
# Generated by ${SCRIPT_DIR}/run.sh

# Conjur JWT authenticator ID
export CONJUR_AUTHN_JWT_AUTHENTICATOR_ID="${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID}"

# Where JWT-based workload identities live in Conjur
export CONJUR_JWT_IDENTITY_PATH="${CONJUR_JWT_IDENTITY_PATH}"

# Auth URL for Conjur tenant
export CONJUR_AUTH_URL="https://${CONJUR_TENANT}.secretsmgr.cyberark.cloud/api/authn-jwt/${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID}/conjur/authenticate"

# Expected audience in JWTs used for Conjur
export CONJUR_JWT_AUDIENCE="${CONJUR_JWT_AUDIENCE}"

# Resource prefix used for policies (workloads, secrets)
export CONJUR_RESOURCE_PREFIX="${CONJUR_RESOURCE_PREFIX}"

# OIDC issuer used by Conjur
export CONJUR_OIDC_ISSUER_URL="${TF_VAR_conjur_oidc_issuer_url}"
# Conjur tenant used in URLs
export CONJUR_TENANT="${CONJUR_TENANT}"

# Conjur Secret URL
export CONJUR_SECRET_URL="https://${CONJUR_TENANT}.secretsmgr.cyberark.cloud/api/secrets/conjur/variable/"

# Sample secert paths
export CONJUR_SAMPLE_TIMEZONE_TOKEN_ID="${CONJUR_TIMEZONE_TOKEN_ID_ENCODED}"
export CONJUR_SAMPLE_OPENWEATHER_API_KEY_ID="${CONJUR_OPENWEATHER_API_KEY_ID_ENCODED}"

EOF

  echo "==> Conjur configuration complete."
}

destroy() {
  require_conjur_login

  echo "==> Destroying Conjur configuration for tenant '${CONJUR_TENANT}' and resource prefix '${CONJUR_RESOURCE_PREFIX}'..."

  # If conjur.env exists, source it to get any overridden names
  if [[ -f "${OUT_ENV}" ]]; then
    # shellcheck disable=SC1090
    source "${OUT_ENV}"
  fi

  local authn_id="${CONJUR_AUTHN_JWT_AUTHENTICATOR_ID:-${CONJUR_RESOURCE_PREFIX}-jwt-authenticator}"

  #
  # 1. Disable the authenticator
  #
  echo "==> Disabling authenticator authn-jwt/${authn_id} (if enabled)..."
  set +e
  conjur authenticator disable --id "authn-jwt/${authn_id}" >/dev/null 2>&1 || true
  set -e

  #
  # 2. Delete authenticator policy branch under conjur/authn-jwt
  #
  echo "==> Deleting authenticator policy branch conjur/authn-jwt/${authn_id}..."
  AUTHN_TEARDOWN_YAML="$(mktemp)"
  cat > "${AUTHN_TEARDOWN_YAML}" <<EOF
- !delete
  record: !policy ${authn_id}
EOF

  set +e
  conjur policy update \
    -b conjur/authn-jwt \
    -f "${AUTHN_TEARDOWN_YAML}" >/dev/null 2>&1 || true
  set -e
  rm -f "${AUTHN_TEARDOWN_YAML}"

  #
  # 3. Delete workload + secrets policies under data/${CONJUR_RESOURCE_PREFIX}
  #
  echo "==> Deleting data/${CONJUR_RESOURCE_PREFIX} workload and secrets policies..."
  DATA_TEARDOWN_YAML="$(mktemp)"
  cat > "${DATA_TEARDOWN_YAML}" <<EOF
- !delete
  record: !policy ${CONJUR_RESOURCE_PREFIX}/workloads
- !delete
  record: !policy ${CONJUR_RESOURCE_PREFIX}/secrets
EOF

  set +e
  conjur policy update \
    -b data \
    -f "${DATA_TEARDOWN_YAML}" >/dev/null 2>&1 || true
  set -e
  rm -f "${DATA_TEARDOWN_YAML}"

  #
  # 4. Remove local env file
  #
  echo "==> Removing ${OUT_ENV}..."
  rm -f "${OUT_ENV}" || true
  echo "==> Removing generated files from ${SCRIPT_DIR}/.generated..."
  rm -rf "${SCRIPT_DIR}/.generated" || true

  echo "==> Destroy complete. Authenticator disabled; Conjur policies and secrets removed."
}

usage() {
  echo "Usage:"
  echo "  $0 create   # configure Conjur (authn-jwt, workloads, secrets, grants) and write conjur.env"
  echo "  $0 destroy  # disable authenticator, delete policies, remove conjur.env"
  exit 1
}

ACTION="${1:-}"
case "${ACTION}" in
  create)  create ;;
  destroy) destroy ;;
  *)       usage  ;;
esac
