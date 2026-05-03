provider "conjur" {
  # CONJUR_APPLIANCE_URL and CONJUR_ACCOUNT are read from the environment
  # (set via common.env).
  #
  # The automation workload authenticates with an API key rather than the
  # interactive CLI session, so it works in non-interactive and CI contexts.
  # Run `admin-setup` first to create the target branch and grant this host
  # read/update/execute on secrets within it.
  login   = var.conjur_login
  api_key = var.conjur_api_key
}
