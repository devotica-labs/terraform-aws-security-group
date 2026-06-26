# Plan-only unit tests — no AWS credentials required.

provider "aws" {
  region                      = "ap-south-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock"
}

variables {
  name   = "unit-test-sg"
  vpc_id = "vpc-0123456789abcdef0"
}

run "security_group_created" {
  command = plan
  assert {
    condition     = aws_security_group.this.name == "unit-test-sg"
    error_message = "security group name must match var.name."
  }
}

run "no_rules_by_default" {
  command = plan
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 0
    error_message = "Expected 0 ingress rules when ingress_rules is empty."
  }
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.this) == 0
    error_message = "Expected 0 egress rules when egress_rules is empty."
  }
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.allow_all) == 0
    error_message = "Expected no allow-all egress rule when create_default_egress_rule is false (the default)."
  }
}

run "ingress_rule_cidr" {
  command = plan
  variables {
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
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 1
    error_message = "Expected exactly 1 ingress rule."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["https"].cidr_ipv4 == "0.0.0.0/0"
    error_message = "Ingress rule cidr_ipv4 must match what was configured."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["https"].from_port == 443
    error_message = "Ingress rule from_port must match what was configured."
  }
}

run "egress_rule_referenced_sg" {
  command = plan
  variables {
    egress_rules = {
      to_rds = {
        description                  = "To the database tier security group"
        from_port                    = 5432
        to_port                      = 5432
        ip_protocol                  = "tcp"
        referenced_security_group_id = "sg-0123456789abcdef0"
      }
    }
  }
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.this) == 1
    error_message = "Expected exactly 1 egress rule."
  }
  assert {
    condition     = aws_vpc_security_group_egress_rule.this["to_rds"].referenced_security_group_id == "sg-0123456789abcdef0"
    error_message = "Egress rule referenced_security_group_id must match what was configured."
  }
}

run "default_egress_rule_opt_in" {
  command = plan
  variables {
    create_default_egress_rule = true
  }
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.allow_all) == 1
    error_message = "Expected the allow-all egress rule when create_default_egress_rule is true."
  }
  assert {
    condition     = aws_vpc_security_group_egress_rule.allow_all[0].cidr_ipv4 == "0.0.0.0/0"
    error_message = "Allow-all egress rule must target 0.0.0.0/0."
  }
  assert {
    condition     = aws_vpc_security_group_egress_rule.allow_all[0].ip_protocol == "-1"
    error_message = "Allow-all egress rule must use protocol -1 (all)."
  }
}

run "multiple_ingress_rules_independent" {
  command = plan
  variables {
    ingress_rules = {
      https = {
        description = "HTTPS"
        from_port   = 443
        to_port     = 443
        ip_protocol = "tcp"
        cidr_ipv4   = "0.0.0.0/0"
      }
      ssh = {
        description = "SSH from office"
        from_port   = 22
        to_port     = 22
        ip_protocol = "tcp"
        cidr_ipv4   = "203.0.113.0/24"
      }
    }
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 2
    error_message = "Expected exactly 2 ingress rules."
  }
}
