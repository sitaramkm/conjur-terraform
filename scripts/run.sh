#!/usr/bin/env bash
set -euo pipefail

# scripts/run.sh — Terraform wrapper for conjur-terraform
#
# Usage:
#   CONJUR_TENANT=<tenant> ./scripts/run.sh create
#   CONJUR_TENANT=<tenant> ./scripts/run.sh destroy
#   ./scripts/run.sh output
#
# Required env vars (provider credentials):
#   CONJUR_TENANT        — tenant name (e.g. mycompany)
#   CONJUR_AUTHN_LOGIN   — Conjur login (e.g. admin)
#   CONJUR_AUTHN_API_KEY — your API key (the password used with conjur login)
#
# CONJUR_APPLIANCE_URL and CONJUR_ACCOUNT are derived automatically.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform"

ACTION="${1:-}"

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

# ── Provider env vars ────────────────────────────────────────
setup_provider_env() {
  : "${CONJUR_TENANT:?Set CONJUR_TENANT before running this script}"
  : "${CONJUR_AUTHN_LOGIN:?Set CONJUR_AUTHN_LOGIN (e.g. export CONJUR_AUTHN_LOGIN=admin)}"
  : "${CONJUR_AUTHN_API_KEY:?Set CONJUR_AUTHN_API_KEY (your Conjur password / API key)}"

  export CONJUR_APPLIANCE_URL="https://${CONJUR_TENANT}.secretsmgr.cyberark.cloud/api"
  export CONJUR_ACCOUNT="conjur"

  echo "==> Provider config"
  echo "    Appliance URL: ${CONJUR_APPLIANCE_URL}"
  echo "    Account:       ${CONJUR_ACCOUNT}"
  echo "    Login:         ${CONJUR_AUTHN_LOGIN}"
}

# ── Terraform vars ───────────────────────────────────────────
set_tf_vars() {
  export TF_VAR_conjur_tenant="${CONJUR_TENANT}"
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

Required env vars:
  CONJUR_TENANT        — Conjur Cloud tenant name
  CONJUR_AUTHN_LOGIN   — Conjur login (e.g. admin)
  CONJUR_AUTHN_API_KEY — API key (the password used with 'conjur login')

Optional:
  TF_VAR_*             — override any Terraform variable directly
EOF
    exit 1
    ;;
esac
