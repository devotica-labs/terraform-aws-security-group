# Integration tests — apply + assert + destroy against real AWS.
# Requires a real AWS account and a real vpc_id. Triggered via
# workflow_dispatch on integration.yml. Run manually:
#   terraform test -filter=tests/integration.tftest.hcl

provider "aws" {
  region = "ap-south-1"
}

variables {
  name   = "integ-test-sg"
  vpc_id = "vpc-REPLACE_WITH_REAL_VPC_ID" # sandbox VPC, from bootstrap output
  tags = {
    Environment = "integration-test"
    Ephemeral   = "true"
  }
  ingress_rules = {
    https = {
      description = "HTTPS from anywhere"
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

run "apply_and_assert" {
  command = apply

  assert {
    condition     = aws_security_group.this.id != ""
    error_message = "Security group was not created."
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 1
    error_message = "Expected exactly 1 ingress rule after apply."
  }
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.allow_all) == 0
    error_message = "No allow-all egress rule should exist without explicit opt-in."
  }
}
