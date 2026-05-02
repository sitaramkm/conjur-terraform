#!/usr/bin/env bash
set -euo pipefail

# scripts/run.sh — Terraform wrapper for conjur-terraform
#
# Usage:
#   ./scripts/run.sh create
#   ./scripts/run.sh destroy
#   ./scripts/run.sh output
#
# Configuration (in order of precedence — last wins):
#   1. common.env at repo root   — copy from common.env.example and fill in values
#   2. Environment variables     — export TF_VAR_* / CONJUR_* before running
#
# Minimum required after loading common.env (or exported directly):
#   CONJUR_TENANT        — tenant name (e.g. mycompany)
#   CONJUR_AUTHN_LOGIN   — Conjur login (e.g. admin)
#   CONJUR_AUTHN_API_KEY — API key (the password used with conjur login)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

ACTION="${1:-}"

# ── Load common.env if present ───────────────────────────────
COMMON_ENV="${ROOT_DIR}/common.env"
if [[ -f "${COMMON_ENV}" ]]; then
  echo "==> Loading configuration from common.env"
  # shellcheck disable=SC1090
  source "${COMMON_ENV}"
fi

# ── Preflight: verify Conjur CLI session ─────────────────────
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
    echo "Please log in first:"
    echo "  conjur login -u <username> -p <api-key>"
    exit 1
  fi

  echo "    $(echo "${WHOAMI_OUTPUT}" | head -n1)"
}

# ── Validate and finalize provider env vars ──────────────────
setup_provider_env() {
  : "${CONJUR_TENANT:?CONJUR_TENANT not set — add it to common.env or export it}"
  : "${CONJUR_AUTHN_LOGIN:?CONJUR_AUTHN_LOGIN not set — add it to common.env or export it}"
  : "${CONJUR_AUTHN_API_KEY:?CONJUR_AUTHN_API_KEY not set — add it to common.env or export it}"

  # Derive these if not already set (e.g. common.env may have set them explicitly)
  export CONJUR_APPLIANCE_URL="${CONJUR_APPLIANCE_URL:-https://${CONJUR_TENANT}.secretsmgr.cyberark.cloud/api}"
  export CONJUR_ACCOUNT="${CONJUR_ACCOUNT:-conjur}"

  echo "==> Provider config"
  echo "    Appliance URL: ${CONJUR_APPLIANCE_URL}"
  echo "    Account:       ${CONJUR_ACCOUNT}"
  echo "    Login:         ${CONJUR_AUTHN_LOGIN}"
}

# ── Ensure TF_VAR_conjur_tenant is set ────────────────────────
# common.env typically sets this directly; fall back to CONJUR_TENANT.
set_tf_vars() {
  export TF_VAR_conjur_tenant="${TF_VAR_conjur_tenant:-${CONJUR_TENANT}}"
}

# ── Actions ──────────────────────────────────────────────────
do_create() {
  require_conjur_login
  setup_provider_env
  set_tf_vars

  cd "${TF_DIR}"
  echo "==> terraform init"
  terraform init -upgrade

  echo "==> terraform plan"
  terraform plan -out=tfplan

  echo "==> terraform apply (parallelism=1 — required by Conjur)"
  terraform apply -parallelism=1 tfplan
  rm -f tfplan

  echo ""
  echo "==> Conjur setup complete. Outputs:"
  terraform output
}

do_destroy() {
  require_conjur_login
  setup_provider_env
  set_tf_vars

  cd "${TF_DIR}"
  echo "==> terraform init"
  terraform init -upgrade

  echo "==> terraform destroy (parallelism=1)"
  terraform destroy -parallelism=1 -auto-approve
}

do_output() {
  cd "${TF_DIR}"
  terraform output
}

# ── Dispatch ─────────────────────────────────────────────────
case "${ACTION}" in
  create)  do_create  ;;
  destroy) do_destroy ;;
  output)  do_output  ;;
  *)
    cat <<-EOF
Usage:
  ./scripts/run.sh create   — bootstrap all Conjur resources and push secrets
  ./scripts/run.sh destroy  — tear down all Conjur resources
  ./scripts/run.sh output   — print Terraform outputs

Configuration:
  Copy common.env.example to common.env and fill in your values.
  run.sh loads common.env automatically if present.

  Minimum required:
    CONJUR_TENANT        — Conjur Cloud tenant name
    CONJUR_AUTHN_LOGIN   — Conjur login (e.g. admin)
    CONJUR_AUTHN_API_KEY — API key (the password used with 'conjur login')

  All TF_VAR_* variables can also be set in common.env or exported directly.
EOF
    exit 1
    ;;
esac
