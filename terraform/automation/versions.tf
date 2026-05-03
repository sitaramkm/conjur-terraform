terraform {
  required_version = ">= 1.11"
  required_providers {
    conjur = {
      source  = "cyberark/conjur"
      version = ">= 0.8.4"
    }
  }
}
