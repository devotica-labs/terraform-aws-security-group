# ---------------------------------------------------------------------------
# Core identity
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name for the security group. Used directly as the SG name and as a prefix for rule Name tags."
  type        = string
  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 255
    error_message = "name must be 1–255 characters."
  }
}

variable "description" {
  description = "Description for the security group."
  type        = string
  default     = "Managed by Terraform (devotica-labs/security-group/aws)"
}

variable "vpc_id" {
  description = "ID of the VPC the security group belongs to."
  type        = string
  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (starts with vpc-)."
  }
}

# ---------------------------------------------------------------------------
# Rules
#
# Uses the modern split-resource model (aws_vpc_security_group_ingress_rule /
# aws_vpc_security_group_egress_rule) rather than inline ingress/egress
# blocks on aws_security_group. The split model avoids the well-documented
# drift and "rule clobbering" issues inline blocks have under for_each /
# multi-author change patterns, and is what the AWS provider has recommended
# since v5.
#
# Each rule must specify EXACTLY ONE of: cidr_ipv4, cidr_ipv6,
# referenced_security_group_id, prefix_list_id — this mirrors the AWS API's
# own constraint on these resources, enforced here at plan time instead of
# surfacing as an apply-time AWS error.
# ---------------------------------------------------------------------------

variable "ingress_rules" {
  description = "Map of inbound rules, keyed by your own descriptive rule name. Each entry must set exactly one of cidr_ipv4 / cidr_ipv6 / referenced_security_group_id / prefix_list_id. Empty by default — no inbound traffic is allowed until you add rules."
  type        = map(object({
    description                  = optional(string)
    from_port                    = number
    to_port                      = number
    ip_protocol                  = string
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
    prefix_list_id               = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, r in var.ingress_rules :
      (
        (r.cidr_ipv4 != null ? 1 : 0) +
        (r.cidr_ipv6 != null ? 1 : 0) +
        (r.referenced_security_group_id != null ? 1 : 0) +
        (r.prefix_list_id != null ? 1 : 0)
      ) == 1
    ])
    error_message = "Each ingress rule must set EXACTLY ONE of: cidr_ipv4, cidr_ipv6, referenced_security_group_id, prefix_list_id."
  }

  validation {
    condition     = alltrue([for k, r in var.ingress_rules : r.from_port <= r.to_port])
    error_message = "Each ingress rule's from_port must be <= to_port."
  }
}

variable "egress_rules" {
  description = "Map of outbound rules, keyed by your own descriptive rule name. Same shape and exactly-one-target constraint as ingress_rules. Empty by default — see create_default_egress_rule for the common 'allow all outbound' case."
  type        = map(object({
    description                  = optional(string)
    from_port                    = number
    to_port                      = number
    ip_protocol                  = string
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
    prefix_list_id               = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, r in var.egress_rules :
      (
        (r.cidr_ipv4 != null ? 1 : 0) +
        (r.cidr_ipv6 != null ? 1 : 0) +
        (r.referenced_security_group_id != null ? 1 : 0) +
        (r.prefix_list_id != null ? 1 : 0)
      ) == 1
    ])
    error_message = "Each egress rule must set EXACTLY ONE of: cidr_ipv4, cidr_ipv6, referenced_security_group_id, prefix_list_id."
  }

  validation {
    condition     = alltrue([for k, r in var.egress_rules : r.from_port <= r.to_port])
    error_message = "Each egress rule's from_port must be <= to_port."
  }
}

variable "create_default_egress_rule" {
  description = "Explicitly create one 'allow all IPv4 outbound' rule (0.0.0.0/0, all protocols). False by default — least privilege. See the comment above aws_vpc_security_group_egress_rule.allow_all in main.tf for an important AWS API caveat: setting this to false does NOT guarantee the security group has zero egress, because AWS's CreateSecurityGroup API auto-creates this exact rule regardless of what Terraform manages. This variable only controls whether Terraform also models/claims that rule explicitly."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags merged onto every resource this module creates."
  type        = map(string)
  default     = {}
}
