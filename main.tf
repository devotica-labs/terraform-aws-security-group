# ---------------------------------------------------------------------------
# Security Group
# ---------------------------------------------------------------------------

resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = var.name })

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Ingress rules
#
# Empty by default (var.ingress_rules = {}) — no inbound traffic is allowed
# until you add rules. AWS's CreateSecurityGroup API does NOT add any
# default inbound rule, so this default genuinely is deny-all-inbound, no
# caveats.
# ---------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = var.ingress_rules

  security_group_id = aws_security_group.this.id
  description       = each.value.description

  from_port   = each.value.from_port
  to_port     = each.value.to_port
  ip_protocol = each.value.ip_protocol

  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  referenced_security_group_id = each.value.referenced_security_group_id
  prefix_list_id               = each.value.prefix_list_id

  tags = merge(local.common_tags, { Name = "${var.name}-ingress-${each.key}" })
}

# ---------------------------------------------------------------------------
# Egress rules
#
# IMPORTANT — AWS API caveat, not a Terraform limitation:
#
# Unlike ingress, AWS's CreateSecurityGroup API automatically attaches ONE
# default egress rule (allow all IPv4 outbound, 0.0.0.0/0) to every new
# security group, regardless of which Terraform resources you use to create
# it. The modern split-resource model used here
# (aws_vpc_security_group_egress_rule) does NOT manage that implicit rule
# unless you explicitly define a matching resource — so leaving
# var.egress_rules empty and create_default_egress_rule = false means
# "Terraform manages zero egress rules", which is NOT the same guarantee as
# "this security group has zero egress in AWS". The AWS-injected default
# rule will still be present, just untracked by Terraform state.
#
# This module does not attempt to silently revoke that implicit rule (doing
# so reliably requires an out-of-band AWS CLI call via a provisioner, which
# would be a fragile dependency for a reusable module). If you need a
# verifiably egress-locked security group, explicitly create
# aws_vpc_security_group_egress_rule resources matching your intended deny
# posture and audit the live AWS console/API for the implicit default rule
# after first apply.
# ---------------------------------------------------------------------------

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = var.egress_rules

  security_group_id = aws_security_group.this.id
  description       = each.value.description

  from_port   = each.value.from_port
  to_port     = each.value.to_port
  ip_protocol = each.value.ip_protocol

  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  referenced_security_group_id = each.value.referenced_security_group_id
  prefix_list_id               = each.value.prefix_list_id

  tags = merge(local.common_tags, { Name = "${var.name}-egress-${each.key}" })
}

# Explicit, opt-in "allow all" egress — deliberately separate from any
# implicit AWS default so that a wide-open rule is visible in the plan,
# auditable in state, and something OPA/conftest can actually flag — the
# same standard applied after the terraform-aws-vpc interface-endpoint
# egress finding (AWS-0104) earlier in this catalog.
resource "aws_vpc_security_group_egress_rule" "allow_all" {
  count = var.create_default_egress_rule ? 1 : 0

  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound IPv4 traffic (explicit opt-in via create_default_egress_rule)"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = merge(local.common_tags, { Name = "${var.name}-egress-allow-all" })
}
