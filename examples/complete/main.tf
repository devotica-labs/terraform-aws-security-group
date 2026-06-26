# ---------------------------------------------------------------------------
# Provider block — CI-friendly skip flags + non-AWS-shaped placeholder creds.
#
# The skip_* flags let `terraform plan` run without calling STS
# GetCallerIdentity / EC2 IMDS. The access_key / secret_key values are
# intentionally NOT AWS-shaped (no AKIA / ASIA prefix, no 40-char base64)
# so gitleaks does not flag them as a leaked AWS access key — they exist
# only to satisfy the provider credential chain.
#
# In a real deployment, drop the skip_* flags AND the placeholder creds,
# and rely on your normal credential chain (OIDC role, profile,
# assume-role, etc.).
# ---------------------------------------------------------------------------
provider "aws" {
  region                      = "ap-south-1"
  access_key                  = "not-a-real-aws-key"
  secret_key                  = "not-a-real-aws-secret"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

module "security_group" {
  source = "../.."

  name        = "sample-prod-app-sg"
  description = "Application tier security group — HTTPS from ALB, egress to RDS and the internet for package updates"
  vpc_id      = "vpc-0123456789abcdef0"

  ingress_rules = {
    https_from_alb = {
      description                  = "HTTPS from the ALB security group"
      from_port                    = 443
      to_port                      = 443
      ip_protocol                  = "tcp"
      referenced_security_group_id = "sg-0123456789abcdef0"
    }
    ssh_from_bastion = {
      description = "SSH from the bastion subnet only"
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      cidr_ipv4   = "10.0.50.0/24"
    }
  }

  egress_rules = {
    postgres_to_rds = {
      description = "PostgreSQL to the isolated database subnet tier"
      from_port   = 5432
      to_port     = 5432
      ip_protocol = "tcp"
      cidr_ipv4   = "10.0.20.0/22"
    }
    https_outbound = {
      description = "HTTPS outbound for package registries and AWS APIs"
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  # Deliberately false — this example shows least-privilege egress instead
  # of opting into the broad allow-all rule. Set to true only when you
  # genuinely need unrestricted outbound and have reviewed the AWS API
  # caveat documented above aws_vpc_security_group_egress_rule.allow_all
  # in main.tf.
  create_default_egress_rule = false

  tags = {
    Environment = "production"
    Project     = "sample"
    Owner       = "cloud-team@example.com"
    CostCenter  = "platform"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-security-group"
  }
}
