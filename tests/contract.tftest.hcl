# Contract tests — lock the output API surface across versions.

provider "aws" {
  region                      = "ap-south-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock"
}

variables {
  name   = "contract-test-sg"
  vpc_id = "vpc-0123456789abcdef0"
}

run "security_group_always_planned" {
  command = plan
  assert {
    condition     = aws_security_group.this.name == "contract-test-sg"
    error_message = "exactly one security group must be planned with the correct name."
  }
}

run "no_egress_rules_without_opt_in" {
  command = plan
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.allow_all) == 0
    error_message = "create_default_egress_rule must default to false — no allow-all egress without explicit opt-in."
  }
}

run "rule_count_matches_input_count" {
  command = plan
  variables {
    ingress_rules = {
      a = { from_port = 80, to_port = 80, ip_protocol = "tcp", cidr_ipv4 = "10.0.0.0/8" }
      b = { from_port = 443, to_port = 443, ip_protocol = "tcp", cidr_ipv4 = "10.0.0.0/8" }
      c = { from_port = 22, to_port = 22, ip_protocol = "tcp", cidr_ipv4 = "10.0.0.0/8" }
    }
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 3
    error_message = "ingress rule count must equal the number of entries in var.ingress_rules."
  }
}
