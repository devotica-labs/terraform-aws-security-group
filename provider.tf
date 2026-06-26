# Provider configuration for the module root.
# Used by the conftest OPA job in CI which runs terraform plan
# without real AWS credentials (backend=false, no OIDC).
#
# skip_credentials_validation = true allows plan generation
# without live AWS auth — safe for module-level static analysis.
#
# NEVER use this provider block in project/consumer repos.
# Project repos (sample-infra, paywolrd-infra) use OIDC auth.

provider "aws" {
  region = "ap-south-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  access_key = "mock"
  secret_key = "mock"
}
