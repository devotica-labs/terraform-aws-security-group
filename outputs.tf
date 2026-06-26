output "security_group_id" {
  description = "ID of the security group."
  value       = aws_security_group.this.id
}

output "security_group_arn" {
  description = "ARN of the security group."
  value       = aws_security_group.this.arn
}

output "security_group_name" {
  description = "Name of the security group."
  value       = aws_security_group.this.name
}

output "ingress_rule_ids" {
  description = "Map of rule key (from var.ingress_rules) to the AWS security group rule ID."
  value       = { for k, r in aws_vpc_security_group_ingress_rule.this : k => r.security_group_rule_id }
}

output "egress_rule_ids" {
  description = "Map of rule key (from var.egress_rules) to the AWS security group rule ID."
  value       = { for k, r in aws_vpc_security_group_egress_rule.this : k => r.security_group_rule_id }
}

output "allow_all_egress_rule_id" {
  description = "AWS security group rule ID of the explicit allow-all egress rule. Empty string when create_default_egress_rule = false."
  value       = length(aws_vpc_security_group_egress_rule.allow_all) > 0 ? aws_vpc_security_group_egress_rule.allow_all[0].security_group_rule_id : ""
}
