provider "conjur" {
  # CONJUR_APPLIANCE_URL and CONJUR_ACCOUNT are read from the environment
  # (set in common.env via conjurapi.LoadConfig).
  #
  # login and api_key are passed explicitly so the provider uses NewClientFromKey
  # rather than NewClientFromEnvironment. NewClientFromEnvironment picks up
  # authn_type: oidc from ~/.conjurrc (written by `conjur login`) and fails
  # because CredentialStorageNone prevents reading the stored OIDC token.
  #
  # To get your API key while your CLI session is active:
  #   conjur user rotate-api-key
  # Then set TF_VAR_conjur_login and TF_VAR_conjur_api_key in common.env.
  login   = var.conjur_login
  api_key = var.conjur_api_key
}
