output "security_group_id" { value = module.security_group.security_group_id }
output "security_group_arn" { value = module.security_group.security_group_arn }
output "security_group_name" { value = module.security_group.security_group_name }
output "ingress_rule_ids" { value = module.security_group.ingress_rule_ids }
output "egress_rule_ids" { value = module.security_group.egress_rule_ids }
output "allow_all_egress_rule_id" { value = module.security_group.allow_all_egress_rule_id }
